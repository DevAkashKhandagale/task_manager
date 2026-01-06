import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_manager/core/constants/app_constants.dart';
import 'package:task_manager/presentation/cubits/task_cubit.dart';

/// Custom search bar widget with debounce and minimum character requirement
/// 
/// Features:
/// - Only triggers search when at least 2 characters are entered
/// - Debounced input to avoid excessive API calls
/// - Clear button appears when text is entered
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({super.key});

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    setState(() {});

    if (query.isEmpty) {
      context.read<TaskCubit>().clearSearch();
      return;
    }

    if (query.length < AppConstants.minSearchCharacters) {
      return;
    }

    _debounceTimer = Timer(
      Duration(milliseconds: AppConstants.searchDebounceMs),
      () {
        if (mounted) {
          context.read<TaskCubit>().searchTasks(query);
        }
      },
    );
  }

  /// Clears the search input and resets the task list
  void _clearSearch() {
    _controller.clear();
    context.read<TaskCubit>().clearSearch();
    setState(() {}); // Update UI to hide clear button
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        return TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search tasks... (min ${AppConstants.minSearchCharacters} chars)',
            prefixIcon: const Icon(Icons.search),
            // Show clear button only when text is entered
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                    tooltip: 'Clear search',
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: _onSearchChanged,
        );
      },
    );
  }
}