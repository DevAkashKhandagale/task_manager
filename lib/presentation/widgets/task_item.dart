import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_manager/domain/entities/task.dart';
import 'package:task_manager/presentation/cubits/task_cubit.dart';

/// Widget representing a single task item in the list
/// 
/// Features:
/// - Swipe-to-delete with confirmation dialog
/// - Tap or checkbox to toggle completion
/// - Shows sync status indicator
/// - Displays task metadata (ID, time ago)
class TaskItem extends StatelessWidget {
  final Task task;
  const TaskItem({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteDialog(context);
      },
      onDismissed: (direction) {
        if (task.id != null) {
          context.read<TaskCubit>().deleteTask(task.id!);
        }
      },
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (_) {
            if (task.id != null) {
              context.read<TaskCubit>().toggleTaskCompletion(task);
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            color: task.completed ? Colors.grey : null,
            fontWeight: task.completed ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        subtitle: _buildSubtitle(),
        trailing: !task.isSynced
            ? const Icon(
                Icons.sync_disabled,
                size: 16,
                color: Colors.orange,
              )
            : null,
        onTap: () {
          if (task.id != null) {
            context.read<TaskCubit>().toggleTaskCompletion(task);
          }
        },
      ),
    );
  }

  /// Builds the subtitle with task metadata
  /// 
  /// Shows:
  /// - Local task ID (if ID < 1000)
  /// - Time ago (when task was created)
  Widget _buildSubtitle() {
    final List<String> details = [];

    // Show ID for local tasks (temporary IDs are typically < 1000)
    if (task.id != null && task.id! < 1000) {
      details.add('ID: ${task.id}');
    }

    // Show time ago if creation date is available
    if (task.createdAt != null) {
      final timeAgo = _getTimeAgo(task.createdAt!);
      details.add(timeAgo);
    }

    // Return empty widget if no details to show
    if (details.isEmpty) return const SizedBox.shrink();

    return Text(
      details.join(' • '),
      style: const TextStyle(fontSize: 12),
    );
  }

  /// Converts DateTime to human-readable "time ago" string
  /// 
  /// Examples:
  /// - "2d ago" (2 days)
  /// - "3h ago" (3 hours)
  /// - "15m ago" (15 minutes)
  /// - "Just now" (less than a minute)
  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Shows confirmation dialog before deleting task
  /// 
  /// Returns true if user confirms deletion, false otherwise
  Future<bool?> _showDeleteDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}