import 'package:task_manager/domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    super.id,
    required super.title,
    required super.completed,
    super.userId,
    super.createdAt,
    super.isSynced,
    super.isDeleted,
  });

  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      title: task.title,
      completed: task.completed,
      userId: task.userId,
      createdAt: task.createdAt,
      isSynced: task.isSynced,
      isDeleted: task.isDeleted,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      completed: json['completed'],
      userId: json['userId'] ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isSynced: json['isSynced'] ?? true,
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Task toEntity() {
    return Task(
      id: id,
      title: title,
      completed: completed,
      userId: userId,
      createdAt: createdAt,
      isSynced: isSynced,
      isDeleted: isDeleted,
    );
  }
}