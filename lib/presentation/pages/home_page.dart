import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_manager/presentation/cubits/task_cubit.dart';
import 'package:task_manager/presentation/widgets/app_search_bar.dart';
import 'package:task_manager/presentation/widgets/loading_indicator.dart';
import 'package:task_manager/presentation/widgets/no_internet_msg.dart';
import 'package:task_manager/presentation/widgets/task_item.dart';

/// Home page of the application
/// 
/// Displays the task list with search, add, and sync functionality
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  /// Loads tasks after the widget tree is built
  /// 
  /// Uses post-frame callback to ensure context is available
  void _loadTasks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskCubit>().loadTasks();
    });
  }

  /// Shows dialog for adding a new task
  /// 
  /// Allows user to enter task title and adds it via TaskCubit
  void _showAddTaskDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter task title',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<TaskCubit>().addTask(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tasks"),
        actions: [
          BlocBuilder<TaskCubit, TaskState>(
            builder: (context, state) {
              if (state is TaskLoaded) {
                if (state.isSyncing) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (state.hasPendingSync) {
                  return IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.sync),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () => context.read<TaskCubit>().syncTasks(),
                    tooltip: 'Sync pending changes',
                  );
                }
              }
              return IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () => context.read<TaskCubit>().refreshTasks(),
                tooltip: 'Refresh',
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          const NoInternetMsg(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppSearchBar(),
          ),
          Expanded(
            child: BlocConsumer<TaskCubit, TaskState>(
              listener: (context, state) {
                if (state is TaskError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              builder: (context, state) {
                return _buildContent(context, state);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the main content based on current state
  /// 
  /// Handles different states:
  /// - TaskLoading: Shows loading indicator
  /// - TaskLoaded: Shows task list or empty state
  /// - TaskError: Shows error message with retry button
  Widget _buildContent(BuildContext context, TaskState state) {
    if (state is TaskLoading) {
      return const LoadingIndicator();
    }

    if (state is TaskLoaded) {
      if (state.isRefreshing) {
        return const LoadingIndicator();
      }

      if (state.tasks.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.checklist_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                state.searchQuery != null
                    ? 'No tasks found for "${state.searchQuery}"'
                    : 'No tasks yet',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              if (state.searchQuery != null)
                TextButton(
                  onPressed: () => context.read<TaskCubit>().clearSearch(),
                  child: const Text('Clear search'),
                ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await context.read<TaskCubit>().refreshTasks();
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.tasks.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final task = state.tasks[index];
            return TaskItem(task: task);
          },
        ),
      );
    }

    if (state is TaskError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<TaskCubit>().loadTasks(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const LoadingIndicator();
  }
}