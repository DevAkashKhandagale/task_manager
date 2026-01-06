part of 'task_cubit.dart';

abstract class TaskState {
  const TaskState();
}


class TaskInitial extends TaskState {}
class TaskLoading extends TaskState {}

class TaskLoaded extends TaskState {
  final List<Task> tasks;
  final String? searchQuery;
  final bool hasPendingSync;
  final bool isRefreshing;
  final bool isSyncing;

  const TaskLoaded({
    required this.tasks,
    this.searchQuery,
    this.hasPendingSync = false,
    this.isRefreshing = false,
    this.isSyncing = false,
  });

  TaskLoaded copyWith({
    List<Task>? tasks,
    String? searchQuery,
    bool? hasPendingSync,
    bool? isRefreshing,
    bool? isSyncing,
  }) {
    return TaskLoaded(
      tasks: tasks ?? this.tasks,
      searchQuery: searchQuery ?? this.searchQuery,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TaskLoaded &&
              runtimeType == other.runtimeType &&
              tasks == other.tasks &&
              searchQuery == other.searchQuery &&
              hasPendingSync == other.hasPendingSync &&
              isRefreshing == other.isRefreshing &&
              isSyncing == other.isSyncing;

  @override
  int get hashCode =>
      tasks.hashCode ^
      searchQuery.hashCode ^
      hasPendingSync.hashCode ^
      isRefreshing.hashCode ^
      isSyncing.hashCode;
}

class TaskError extends TaskState {
  final String message;

  const TaskError({required this.message});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TaskError &&
              runtimeType == other.runtimeType &&
              message == other.message;

  @override
  int get hashCode => message.hashCode;
}