import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_manager/core/constants/app_constants.dart';
import 'package:task_manager/domain/entities/task.dart';
import 'package:task_manager/domain/repositories/task_repository.dart';
part 'task_state.dart';

/// Business logic cubit for managing task operations
/// 
/// Handles:
/// - Loading tasks from API/local database
/// - CRUD operations (Create, Read, Update, Delete)
/// - Search functionality with debounce
/// - Offline/online sync
/// - Connectivity monitoring
class TaskCubit extends Cubit<TaskState> {
  /// Repository for data operations (API and local database)
  final TaskRepository _taskRepository;
  /// Connectivity service for checking network status
  final Connectivity _connectivity;
  /// Subscription to connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  /// Timer for periodic background sync
  Timer? _syncTimer;
  /// Timer for debouncing search input
  Timer? _searchDebounceTimer;

  /// Constructor for TaskCubit
  /// 
  /// Initializes the cubit with required dependencies and sets up
  /// connectivity monitoring and periodic sync
  TaskCubit({
    required TaskRepository taskRepository,
    required Connectivity connectivity,
  })  : _taskRepository = taskRepository,
        _connectivity = connectivity,
        super(TaskInitial()) {
    _init();
  }

  /// Initializes connectivity monitoring and periodic sync
  void _init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (_isConnected(results)) {
          _syncTasks();
        }
      },
    );
    _startPeriodicSync();
  }

  /// Helper method to check if connectivity results indicate online status
  /// 
  /// Returns true if any result is not ConnectivityResult.none
  bool _isConnected(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        !results.contains(ConnectivityResult.none) &&
        results.any((result) => result != ConnectivityResult.none);
  }

  /// Loads tasks from API or local database
  /// 
  /// Strategy:
  /// - If online: Fetches from API and caches locally
  /// - If offline: Loads from local database
  /// - Shows loading indicator only if no tasks are currently displayed
  Future<void> loadTasks() async {
    if (state is! TaskLoaded || (state as TaskLoaded).tasks.isEmpty) {
      emit(TaskLoading());
    }

    try {
      final tasks = await _taskRepository.getTasks();
      final hasPendingSync = await _taskRepository.hasPendingSync();
      
      emit(TaskLoaded(
        tasks: tasks,
        hasPendingSync: hasPendingSync,
      ));
    } catch (e) {
      emit(TaskError(message: 'Failed to load tasks: $e'));
    }
  }

  /// Adds a new task with optimistic UI update
  /// 
  /// Process:
  /// 1. Validates input
  /// 2. Creates task with temporary ID
  /// 3. Immediately shows in UI (optimistic update)
  /// 4. Saves to repository (handles offline/online)
  /// 5. Reloads if server ID was assigned
  /// 
  /// Uses optimistic updates for better UX - task appears instantly
  Future<void> addTask(String title) async {
    if (title.trim().isEmpty) {
      emit(TaskError(message: 'Task title cannot be empty'));
      return;
    }

    final currentState = state;
    if (currentState is TaskLoaded) {
      final tempId = DateTime.now().millisecondsSinceEpoch;

      // Create task with optimistic update flag
      final newTask = Task(
        id: tempId,
        title: title.trim(),
        completed: false,
        userId: 1,
        createdAt: DateTime.now(),
        isSynced: false, // Mark as unsynced until server confirms
      );

      final updatedTasks = [newTask, ...currentState.tasks];
      emit(currentState.copyWith(
        tasks: updatedTasks,
        hasPendingSync: true, // Mark that sync is needed
        isRefreshing: false,
      ));

      try {
        final savedTask = await _taskRepository.addTask(newTask);

        if (savedTask.id != null && savedTask.id != tempId && savedTask.isSynced) {
          await loadTasks();
        }
      } catch (e) {
        await loadTasks();
        final reloadedState = state;
        if (reloadedState is TaskLoaded) {
          return;
        }
        emit(TaskError(message: 'Failed to save task: $e'));
      }
    } else {
      emit(TaskError(message: 'Cannot add task - app not ready'));
    }
  }

  /// Toggles task completion status with optimistic update
  /// 
  /// Immediately updates UI, then syncs with backend
  /// If sync fails, reloads to show actual state
  Future<void> toggleTaskCompletion(Task task) async {
    final currentState = state;
    if (currentState is TaskLoaded) {
      final updatedTask = task.copyWith(
        completed: !task.completed,
        isSynced: false,
      );

      final updatedTasks = currentState.tasks.map((t) {
        return t.id == task.id ? updatedTask : t;
      }).toList();

      emit(currentState.copyWith(
        tasks: updatedTasks,
        hasPendingSync: true,
      ));

      try {
        await _taskRepository.updateTask(updatedTask);
      } catch (e) {
        await loadTasks();
        final reloadedState = state;
        if (reloadedState is! TaskLoaded) {
          emit(TaskError(message: 'Failed to update task: $e'));
        }
      }
    }
  }

  /// Deletes a task with optimistic update
  /// 
  /// Immediately removes from UI, then syncs deletion with backend
  /// If sync fails, reloads to show actual state
  Future<void> deleteTask(int taskId) async {
    final currentState = state;
    if (currentState is TaskLoaded) {
      final updatedTasks = currentState.tasks
          .where((task) => task.id != taskId)
          .toList();

      emit(currentState.copyWith(
        tasks: updatedTasks,
        hasPendingSync: true,
      ));

      try {
        await _taskRepository.deleteTask(taskId);
      } catch (e) {
        await loadTasks();
        final reloadedState = state;
        if (reloadedState is! TaskLoaded) {
          emit(TaskError(message: 'Failed to delete task: $e'));
        }
      }
    }
  }

  /// Searches tasks with debounce and minimum character requirement
  /// 
  /// Requirements:
  /// - Query must have at least [AppConstants.minSearchCharacters] characters
  /// - Empty query clears search and loads all tasks
  /// - Uses debounce to avoid excessive database queries
  void searchTasks(String query) {
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      clearSearch();
      return;
    }

    if (query.length < AppConstants.minSearchCharacters) {
      final currentState = state;
      if (currentState is TaskLoaded && currentState.searchQuery != null) {
        return;
      }
      return;
    }

    _searchDebounceTimer = Timer(
      Duration(milliseconds: AppConstants.searchDebounceMs),
      () async {
        final currentState = state;
        if (currentState is TaskLoaded) {
          emit(TaskLoading());
          try {
            final filteredTasks = await _taskRepository.searchTasks(query);
            emit(currentState.copyWith(
              tasks: filteredTasks,
              searchQuery: query,
              isRefreshing: false,
            ));
          } catch (e) {
            emit(TaskError(message: 'Failed to search tasks: $e'));
          }
        }
      },
    );
  }

  /// Refreshes tasks (used for pull-to-refresh)
  /// 
  /// Shows refreshing indicator while fetching latest data
  /// Preserves current state if refresh fails
  Future<void> refreshTasks() async {
    final currentState = state;
    if (currentState is TaskLoaded) {
      emit(currentState.copyWith(isRefreshing: true));
    }

    try {
      await loadTasks();
    } catch (e) {
      if (currentState is TaskLoaded) {
        emit(currentState.copyWith(isRefreshing: false));
      }
      emit(TaskError(message: 'Failed to refresh tasks: $e'));
    }
  }

  /// Syncs pending tasks with server
  /// 
  /// Attempts to sync all unsynced changes (create, update, delete)
  /// Shows syncing indicator during the operation
  Future<void> syncTasks() async {
    final currentState = state;
    if (currentState is TaskLoaded) {
      emit(currentState.copyWith(isSyncing: true));

      try {
        await _taskRepository.syncTasks();
        await loadTasks();
      } catch (e) {
        emit(currentState.copyWith(isSyncing: false));
        emit(TaskError(message: 'Failed to sync tasks: $e'));
      }
    }
  }

  /// Clears search and shows all tasks
  /// 
  /// Resets search query and reloads complete task list
  void clearSearch() {
    final currentState = state;
    if (currentState is TaskLoaded) {
      emit(currentState.copyWith(searchQuery: null));
      loadTasks();
    }
  }

  /// Gets a task by its ID (helper method)
  /// 
  /// Returns null if task is not found or state is not TaskLoaded
  Task? getTaskById(int id) {
    final currentState = state;
    if (currentState is TaskLoaded) {
      return currentState.tasks.firstWhere(
        (task) => task.id == id,
        orElse: () => Task(title: '', completed: false),
      );
    }
    return null;
  }

  /// Starts periodic background sync
  /// 
  /// Syncs pending changes every [AppConstants.syncInterval] minutes
  /// Runs silently in the background without UI updates
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      AppConstants.syncInterval,
      (_) => _syncTasks(),
    );
  }

  /// Internal sync method for background operations
  /// 
  /// Runs silently without emitting state changes
  /// Used for periodic sync and connectivity restoration
  Future<void> _syncTasks() async {
    try {
      await _taskRepository.syncTasks();
    } catch (e) {
      debugPrint("Exception ${e.toString()}");
    }
  }

  /// Checks if user is currently online
  /// 
  /// Returns true if connected to any network (WiFi, mobile, etc.)
  Future<bool> isOnline() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    return _isConnected(connectivityResults);
  }

  /// Disposes all resources to prevent memory leaks
  /// 
  /// Cancels all timers and subscriptions
  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}