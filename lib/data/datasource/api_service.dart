import 'package:dio/dio.dart';
import 'package:task_manager/core/constants/app_constants.dart';
import 'package:task_manager/domain/entities/task.dart';

/// Service for making API calls to the task management backend
/// 
/// Handles all HTTP operations (GET, POST, PATCH, DELETE) with proper
/// timeout configuration and error handling.
class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  )) {
    _setupInterceptors();
  }

  /// Sets up Dio interceptors for request/response handling
  /// 
  /// Currently used for potential logging or request modification
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        return handler.next(options);
      },
      onError: (error, handler) async {
        return handler.next(error);
      },
    ));
  }

  /// Fetches tasks from the API
  /// 
  /// [limit] - Maximum number of tasks to fetch (default: 20)
  /// Returns list of tasks from the server
  Future<List<Task>> getTasks({int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/todos',
        queryParameters: {'_limit': limit},
      );

      final List<dynamic> data = response.data;
      return data.map((json) => Task.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Failed to load tasks: $e');
    }
  }

  /// Creates a new task on the server
  /// 
  /// Returns the created task with server-assigned ID
  /// No artificial delays - request is sent immediately
  Future<Task> createTask(Task task) async {
    try {
      final response = await _dio.post(
        '/todos',
        data: {
          'title': task.title,
          'completed': task.completed,
          'userId': task.userId,
        },
      );

      return Task.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Updates an existing task on the server
  /// 
  /// [task] - Task with updated data
  /// Returns the updated task from server
  Future<Task> updateTask(Task task) async {
    try {
      final response = await _dio.patch(
        '/todos/${task.id}',
        data: {
          'completed': task.completed,
          'title': task.title,
        },
      );

      return Task.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Deletes a task from the server
  /// 
  /// [id] - ID of the task to delete
  Future<void> deleteTask(int id) async {
    try {
      await _dio.delete('/todos/$id');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet.');
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 404) {
          return Exception('Resource not found');
        } else if (error.response?.statusCode == 500) {
          return Exception('Server error');
        }
        return Exception('Failed with status: ${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return Exception('Request cancelled');
      case DioExceptionType.unknown:
        return Exception('Network error. Please check your connection.');
      default:
        return Exception('An error occurred: ${error.message}');
    }
  }
}