import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:task_manager/core/constants/app_constants.dart';
import 'package:task_manager/domain/entities/task.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        userId INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        serverId INTEGER,
        lastUpdated TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_synced ON tasks(isSynced)
    ''');

    await db.execute('''
      CREATE INDEX idx_deleted ON tasks(isDeleted)
    ''');
  }

  // Helper method to convert Task to Map for SQLite
  Map<String, dynamic> _taskToMap(Task task) {
    return {
      if (task.id != null && task.id! < 1000) 'id': task.id,
      'title': task.title,
      'completed': task.completed ? 1 : 0, // Convert bool to int
      'userId': task.userId,
      'createdAt': task.createdAt?.toIso8601String(),
      'isSynced': task.isSynced ? 1 : 0, // Convert bool to int
      'isDeleted': task.isDeleted ? 1 : 0, // Convert bool to int
      if (task.id != null && task.id! >= 1000) 'serverId': task.id,
    };
  }

  // Helper method to convert Map to Task
  Task _mapToTask(Map<String, dynamic> map) {
    return Task(
      id: map['serverId'] ?? map['id'],
      title: map['title'],
      completed: map['completed'] == 1, // Convert int to bool
      userId: map['userId'] ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isSynced: map['isSynced'] == 1, // Convert int to bool
      isDeleted: map['isDeleted'] == 1, // Convert int to bool
    );
  }

  Future<int> insertTask(Task task) async {
    final db = await database;

    final taskMap = _taskToMap(task);
    // Set lastUpdated to current time so new tasks appear at the top
    taskMap['lastUpdated'] = DateTime.now().toIso8601String();

    return await db.insert(
      'tasks',
      taskMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'isDeleted = 0',
      orderBy: 'completed ASC, lastUpdated DESC',
    );

    return maps.map((map) => _mapToTask(map)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;

    final taskMap = _taskToMap(task);
    taskMap['lastUpdated'] = DateTime.now().toIso8601String();

    return await db.update(
      'tasks',
      taskMap,
      where: 'id = ? OR serverId = ?',
      whereArgs: [task.id, task.id],
    );
  }

  Future<int> markTaskAsDeleted(int id) async {
    final db = await database;

    return await db.update(
      'tasks',
      {
        'isDeleted': 1,
        'isSynced': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      },
      where: 'id = ? OR serverId = ?',
      whereArgs: [id, id],
    );
  }

  Future<List<Task>> getUnsyncedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'isSynced = 0 OR isDeleted = 1',
    );

    return maps.map((map) => _mapToTask(map)).toList();
  }

  Future<void> markTaskAsSynced(int id) async {
    final db = await database;

    await db.update(
      'tasks',
      {
        'isSynced': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
      },
      where: 'id = ? OR serverId = ?',
      whereArgs: [id, id],
    );
  }

  Future<List<Task>> searchTasks(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'isDeleted = 0 AND title LIKE ?',
      whereArgs: ['%$query%'],
    );

    return maps.map((map) => _mapToTask(map)).toList();
  }

  /// Deletes a task permanently by ID
  /// 
  /// Used when replacing a local task with server task
  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ? OR serverId = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('tasks');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}