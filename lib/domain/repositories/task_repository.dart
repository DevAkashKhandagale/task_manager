import 'package:task_manager/domain/entities/task.dart';

abstract class TaskRepository{
  Future<List<Task>> getTasks();
  Future<Task> addTask(Task task);
  Future<Task> updateTask(Task task);
  Future<void> deleteTask(int id);
  Future<List<Task>> searchTasks(String query);
  Future<void> syncTasks();
  Future<bool> hasPendingSync();
}