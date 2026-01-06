# Task Manager

A Flutter application for managing tasks with robust offline support, built using Clean Architecture and the BLoC pattern.

## Features

- ✅ Create, read, update, and delete tasks
- 🔍 Real-time search with debouncing
- 📱 Full offline support with local SQLite database
- 🔄 Automatic synchronization when connection is restored
- ⚡ Optimistic UI updates for instant feedback
- 🌐 Connectivity monitoring with visual indicators
- 🔁 Periodic background sync

## Setup Instructions

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- An IDE with Flutter support (VS Code, Android Studio, or IntelliJ IDEA)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/DevAkashKhandagale/task_manager.git
   cd task_manager
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For Android
   flutter run

   # For iOS (macOS only)
   flutter run

   # For a specific device
   flutter devices  # List available devices
   flutter run -d <device-id>
   ```

4. **Build the application**
   ```bash
   # Android APK
   flutter build apk

   # iOS (macOS only)
   flutter build ios
   ```

### Configuration

The app uses [JSONPlaceholder](https://jsonplaceholder.typicode.com) as the backend API. The base URL is configured in `lib/core/constants/app_constants.dart`:

```dart
static const String apiBaseUrl = 'https://jsonplaceholder.typicode.com';
```

To use a different backend, update this constant and ensure your API follows the same structure.

## Architecture & Design Decisions

### Clean Architecture

The project follows **Clean Architecture** principles with clear separation of concerns:

- **Domain Layer** (`lib/domain/`): Business logic and entities
  - Contains pure Dart classes with no external dependencies
  - Defines repository interfaces (contracts)
  - Entities represent core business objects

- **Data Layer** (`lib/data/`): Data sources and repository implementations
  - `datasource/`: API service and local database
  - `models/`: Data transfer objects (DTOs)
  - `repositories/`: Implementation of domain repository interfaces

- **Presentation Layer** (`lib/presentation/`): UI and state management
  - `cubits/`: Business logic for UI
  - `pages/`: Screen widgets
  - `widgets/`: Reusable UI components

### Dependency Injection

Uses **GetIt** for dependency injection:
- **Singleton** registration for services (API, Database, Repository)
- **Factory** registration for Cubits (allows multiple instances for testing)
- Centralized dependency setup in `lib/core/di_container.dart`

### Key Design Decisions

1. **Repository Pattern**: Abstracts data sources (API and local database) behind a single interface, making the app resilient to changes in data layer implementation.

2. **Optimistic Updates**: Tasks appear instantly in the UI before server confirmation, providing better user experience. If sync fails, the app reloads to show actual state.

3. **Soft Deletes**: Tasks are marked as deleted (`isDeleted` flag) rather than permanently removed, allowing for recovery and proper sync handling.

4. **Local vs Server IDs**: 
   - Local tasks use timestamps as temporary IDs (e.g., `DateTime.now().millisecondsSinceEpoch`)
   - Server tasks use IDs from the API
   - Threshold of 1,000,000 distinguishes local IDs from server IDs
   - Local tasks are replaced with server tasks after successful sync

5. **Search Strategy**: 
   - Search is performed locally on SQLite database for fast, offline-capable results
   - Minimum 2 characters required to trigger search
   - Debounced input (500ms) to reduce database queries

6. **Connectivity Monitoring**: Uses `connectivity_plus` package to monitor network status and automatically sync when connection is restored.

## BLoC Pattern Implementation

### Overview

This app uses the **Cubit** pattern (a simplified version of BLoC) from the `flutter_bloc` package. Cubit provides a reactive state management solution where:

- **State** represents the current UI state
- **Cubit** contains business logic and emits new states
- **UI** listens to state changes and rebuilds accordingly

### State Classes

The app defines the following states in `lib/presentation/cubits/task_state.dart`:

- `TaskInitial`: Initial state when the app starts
- `TaskLoading`: State while fetching tasks
- `TaskLoaded`: State with task data and UI flags:
  - `tasks`: List of tasks
  - `searchQuery`: Current search query (if any)
  - `hasPendingSync`: Whether there are unsynced changes
  - `isRefreshing`: Whether a refresh is in progress
  - `isSyncing`: Whether a sync operation is in progress
- `TaskError`: Error state with error message

### TaskCubit

The `TaskCubit` class (`lib/presentation/cubits/task_cubit.dart`) manages all task-related business logic:

**Key Methods:**
- `loadTasks()`: Fetches tasks from repository (API or local DB)
- `addTask()`: Creates a new task with optimistic update
- `toggleTaskCompletion()`: Updates task completion status
- `deleteTask()`: Deletes a task with optimistic update
- `searchTasks()`: Searches tasks with debouncing
- `syncTasks()`: Manually triggers synchronization
- `refreshTasks()`: Pull-to-refresh functionality

**Connectivity Monitoring:**
- Listens to connectivity changes via `connectivity_plus`
- Automatically syncs when connection is restored
- Runs periodic background sync every 5 minutes

**Resource Management:**
- Properly disposes of timers and subscriptions in `close()` method
- Prevents memory leaks by canceling all async operations

### Usage in UI

```dart
// Accessing the cubit
final cubit = context.read<TaskCubit>();

// Listening to state changes
BlocBuilder<TaskCubit, TaskState>(
  builder: (context, state) {
    if (state is TaskLoaded) {
      return TaskList(tasks: state.tasks);
    }
    return LoadingIndicator();
  },
)

// Calling cubit methods
cubit.addTask('New Task');
cubit.toggleTaskCompletion(task);
```

## Offline Support Strategy

### Overview

The app provides seamless offline functionality using a **local-first** approach with automatic synchronization.

### Components

1. **Local Database (SQLite)**
   - Uses `sqflite` package for local storage
   - Database file: `tasks.db`
   - Stores all task data with sync status flags

2. **Sync Status Tracking**
   - `isSynced`: Boolean flag indicating if task is synced with server
   - `isDeleted`: Boolean flag for soft deletes
   - Indexes on `isSynced` and `isDeleted` for efficient queries

3. **Connectivity Monitoring**
   - Uses `connectivity_plus` package
   - Monitors network status in real-time
   - Automatically triggers sync when connection is restored

### Offline Strategy Details

#### Reading Tasks

- **Online**: 
  1. Sync pending changes first
  2. Fetch from API
  3. Merge with local tasks (API takes precedence)
  4. Cache merged results locally
  5. Return merged list

- **Offline**: 
  - Load directly from local database
  - No API calls attempted

#### Creating Tasks

1. Generate temporary local ID (timestamp)
2. Save to local database immediately (`isSynced = false`)
3. Update UI optimistically
4. If online, attempt API call:
   - On success: Replace local task with server task
   - On failure: Keep local task for later sync
5. If offline: Task remains local until sync

#### Updating Tasks

1. Update local database immediately (`isSynced = false`)
2. Update UI optimistically
3. If online, attempt API call:
   - On success: Mark as synced
   - On failure: Keep for later sync
4. If offline: Change remains local until sync

#### Deleting Tasks

1. Mark as deleted locally (`isDeleted = true`, `isSynced = false`)
2. Remove from UI optimistically
3. If online, attempt API deletion:
   - On success: Mark as synced
   - On failure: Keep for later sync
4. If offline: Deletion remains pending until sync

#### Synchronization

**Automatic Sync Triggers:**
- When connection is restored (via connectivity listener)
- Every 5 minutes in background (periodic timer)
- Manual sync via UI button

**Sync Process:**
1. Check connectivity
2. Fetch all unsynced tasks (`isSynced = false` or `isDeleted = true`)
3. For each unsynced task:
   - **Deleted tasks**: Call API delete, then mark as synced
   - **New tasks** (local ID): Call API create, replace local with server task
   - **Updated tasks** (server ID): Call API update, mark as synced
4. Continue on errors (don't stop sync for one failure)

**Merge Strategy:**
- When fetching tasks online, merge API and local data
- API tasks take precedence (server is source of truth)
- Local-only tasks (not in API) are included in merged list
- After merge, local database is cleared and repopulated with merged data

### Benefits

- ✅ **Instant UI Updates**: Users see changes immediately
- ✅ **Offline Functionality**: Full CRUD operations work offline
- ✅ **Data Persistence**: All data stored locally, survives app restarts
- ✅ **Automatic Sync**: No manual intervention needed
- ✅ **Conflict Resolution**: Server data takes precedence on merge
- ✅ **Resilient**: Handles network failures gracefully

## Challenges Faced & Solutions

### Challenge 1: Managing Local vs Server Task IDs

**Problem**: When creating tasks offline, we need temporary IDs. When syncing, the server assigns new IDs. We needed to distinguish between local and server IDs and handle replacement.

**Solution**: 
- Use timestamp-based IDs for local tasks (e.g., `DateTime.now().millisecondsSinceEpoch`)
- Set threshold of 1,000,000 to distinguish local IDs from server IDs
- When server task is created, delete local task and insert server task with new ID
- Store both `id` and `serverId` in database for flexibility

### Challenge 2: Optimistic Updates with Rollback

**Problem**: Optimistic updates make UI feel instant, but we need to handle cases where server operations fail.

**Solution**:
- Always save to local database first (source of truth)
- Update UI optimistically
- If server operation fails, reload from local database
- This ensures UI always reflects actual stored state

### Challenge 3: Merging Local and Server Data

**Problem**: When going online, we need to merge local changes with server data without losing information.

**Solution**:
- Create a map of API tasks by ID
- Add all API tasks to merged list
- For local tasks, only add if not present in API (prevents duplicates)
- Clear local database and repopulate with merged data
- This ensures local database always matches what's displayed

### Challenge 4: Handling Concurrent Operations

**Problem**: Multiple sync operations could run simultaneously, causing conflicts.

**Solution**:
- Sync operations are sequential (one at a time)
- Repository handles sync logic, preventing race conditions
- Use `isSynced` flag to track sync status
- Background sync runs silently without UI updates

### Challenge 5: Search Performance

**Problem**: Searching through large task lists could be slow, especially with frequent input.

**Solution**:
- Perform search on local SQLite database (fast indexed queries)
- Implement debouncing (500ms delay) to reduce query frequency
- Require minimum 2 characters before searching
- Use SQL `LIKE` queries with indexes for efficient searching

### Challenge 6: Memory Management

**Problem**: Long-running timers and subscriptions could cause memory leaks.

**Solution**:
- Properly dispose of all resources in `close()` method
- Cancel timers and subscriptions when cubit is disposed
- Use `mounted` checks before `setState()` in widgets
- Clean up connectivity subscriptions in widget dispose methods

## Project Structure

```
lib/
├── core/
│   ├── constants/       # App-wide constants
│   ├── di_container.dart # Dependency injection setup
│   ├── errors/          # Custom error classes
│   └── utils/           # Utility functions
├── data/
│   ├── datasource/      # API service and local database
│   ├── models/          # Data models (DTOs)
│   └── repositories/    # Repository implementations
├── domain/
│   ├── entities/        # Business entities
│   └── repositories/    # Repository interfaces
├── presentation/
│   ├── cubits/          # State management (Cubit)
│   ├── pages/           # Screen widgets
│   └── widgets/         # Reusable UI components
└── main.dart            # App entry point
```

## Dependencies

### Core Dependencies
- `flutter_bloc: ^9.1.1` - State management
- `dio: ^5.9.0` - HTTP client
- `sqflite: ^2.4.2` - Local SQLite database
- `connectivity_plus: ^7.0.0` - Network connectivity monitoring
- `get_it: ^9.2.0` - Dependency injection
- `equatable: ^2.0.8` - Value equality for entities

### Dev Dependencies
- `flutter_test` - Testing framework
- `flutter_lints: ^5.0.0` - Linting rules

## Testing

Run tests with:
```bash
flutter test
```

## Future Enhancements
- [ ] Implement task categories/tags
- [ ] Add due dates and reminders
- [ ] Dark mode theme customization
- [ ] Export/import functionality
