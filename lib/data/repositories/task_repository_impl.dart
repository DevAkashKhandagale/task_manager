import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:task_manager/core/constants/app_constants.dart';
import 'package:task_manager/core/errors/api_errors.dart';
import 'package:task_manager/data/datasource/api_service.dart';
import 'package:task_manager/data/datasource/local_database.dart';
import 'package:task_manager/domain/entities/task.dart';
import 'package:task_manager/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final ApiService _apiService;
  final LocalDatabase _localDatabase;
  final Connectivity _connectivity;

  TaskRepositoryImpl({
    required ApiService apiService,
    required LocalDatabase localDatabase,
    required Connectivity connectivity,
  })  : _apiService = apiService,
        _localDatabase = localDatabase,
        _connectivity = connectivity;

  @override
  Future<List<Task>> getTasks() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final isConnected = _isConnected(connectivityResults);

      if (isConnected) {
        try {
          await _syncPendingTasks();

          final apiTasks = await _apiService.getTasks();
          final localTasks = await _localDatabase.getAllTasks();

          final apiTaskMap = {
            for (var task in apiTasks) task.id: task
          };

          final mergedTasks = <Task>[];

          mergedTasks.addAll(apiTasks);

          for (final localTask in localTasks) {
            if (localTask.id != null) {
              final isInApi = apiTaskMap.containsKey(localTask.id);
              if (!isInApi) {
                mergedTasks.add(localTask);
              }
            }
          }

          await _localDatabase.clearDatabase();
          for (final task in mergedTasks) {
            await _localDatabase.insertTask(task);
          }

          return mergedTasks;
        } catch (e) {
          // If API fails, fall back to local storage
          return await _localDatabase.getAllTasks();
        }
      } else {
        // Offline: get from local storage
        return await _localDatabase.getAllTasks();
      }
    } catch (e) {
      throw CacheError('Failed to load tasks: $e');
    }
  }

  @override
  Future<Task> addTask(Task task) async {
    try {
      final newTask = task.copyWith(
        id: task.id ?? DateTime.now().millisecondsSinceEpoch,
        createdAt: task.createdAt ?? DateTime.now(),
        isSynced: false,
      );

      await _localDatabase.insertTask(newTask);

      final connectivityResults = await _connectivity.checkConnectivity();
      final isConnected = _isConnected(connectivityResults);

      if (isConnected) {
        try {
          final serverTask = await _apiService.createTask(newTask);

          await _localDatabase.deleteTask(newTask.id!);
          await _localDatabase.insertTask(
            serverTask.copyWith(isSynced: true),
          );

          return serverTask;
        } catch (e) {
          return newTask;
        }
      }

      return newTask;
    } catch (e) {
      throw CacheError('Failed to add task: $e');
    }
  }

  @override
  Future<Task> updateTask(Task task) async {
    try {
      final updatedTask = task.copyWith(isSynced: false);

      await _localDatabase.updateTask(updatedTask);

      final connectivityResults = await _connectivity.checkConnectivity();
      final isConnected = _isConnected(connectivityResults);

      if (isConnected && task.id != null) {
        try {
          final serverTask = await _apiService.updateTask(updatedTask);
          await _localDatabase.updateTask(
            serverTask.copyWith(isSynced: true),
          );
          return serverTask;
        } catch (e) {
          return updatedTask;
        }
      }

      return updatedTask;
    } catch (e) {
      throw CacheError('Failed to update task: $e');
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    try {
      await _localDatabase.markTaskAsDeleted(id);

      final connectivityResults = await _connectivity.checkConnectivity();
      final isConnected = _isConnected(connectivityResults);

      if (isConnected) {
        try {
          await _apiService.deleteTask(id);
          await _localDatabase.markTaskAsSynced(id);
        } catch (e) {
          // Deletion will be synced later
        }
      }
    } catch (e) {
      throw CacheError('Failed to delete task: $e');
    }
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    try {
      return await _localDatabase.searchTasks(query);
    } catch (e) {
      throw CacheError('Failed to search tasks: $e');
    }
  }

  @override
  Future<void> syncTasks() async {
    try {
      await _syncPendingTasks();
    } catch (e) {
      throw CacheError('Failed to sync tasks: $e');
    }
  }

  @override
  Future<bool> hasPendingSync() async {
    try {
      final unsyncedTasks = await _localDatabase.getUnsyncedTasks();
      return unsyncedTasks.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to check if connectivity results indicate online status
  /// 
  /// Returns true if any result is not ConnectivityResult.none
  bool _isConnected(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        !results.contains(ConnectivityResult.none) &&
        results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> _syncPendingTasks() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    final isConnected = _isConnected(connectivityResults);

    if (!isConnected) return;

    final unsyncedTasks = await _localDatabase.getUnsyncedTasks();

    for (final task in unsyncedTasks) {
      try {
        if (task.isDeleted) {
          final isServerTask = task.id != null && 
              task.id! < AppConstants.localTaskIdThreshold;
          
          if (isServerTask) {
            await _apiService.deleteTask(task.id!);
          }
          await _localDatabase.markTaskAsSynced(task.id!);
        } else if (!task.isSynced) {
          final localId = task.id;
          final isServerTask = task.id != null && 
              task.id! < AppConstants.localTaskIdThreshold;
          
          if (isServerTask) {
            final updatedTask = await _apiService.updateTask(task);
            await _localDatabase.updateTask(
              updatedTask.copyWith(isSynced: true),
            );
          } else {
            final createdTask = await _apiService.createTask(task);
            if (localId != null) {
              await _localDatabase.deleteTask(localId);
            }
            await _localDatabase.insertTask(
              createdTask.copyWith(isSynced: true),
            );
          }
        }
      } catch (e) {
        continue;
      }
    }
  }

  Future<void> dispose() async {
    await _localDatabase.close();
  }
}