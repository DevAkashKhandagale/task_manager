class AppConstants {
  static const String apiBaseUrl = 'https://jsonplaceholder.typicode.com';

  /// Database Configuration
  static const String databaseName = 'tasks.db';
  static const int databaseVersion = 1;

  /// Sync Configuration
  static const int syncRetryCount = 3;
  static const Duration syncInterval = Duration(minutes: 5);

  /// Search Configuration
  static const int minSearchCharacters = 2;
  static const int searchDebounceMs = 500;

  /// Task ID Configuration
  /// Threshold for local task IDs (IDs above this are considered server IDs)
  static const int localTaskIdThreshold = 1000000;
}