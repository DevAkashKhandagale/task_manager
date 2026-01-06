import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:task_manager/data/datasource/api_service.dart';
import 'package:task_manager/data/datasource/local_database.dart';
import 'package:task_manager/data/repositories/task_repository_impl.dart';
import 'package:task_manager/domain/repositories/task_repository.dart';
import 'package:task_manager/presentation/cubits/task_cubit.dart';


final getIt = GetIt.instance;

Future<void> initDependencies() async {

  getIt.registerLazySingleton(() => Connectivity());

  /// Data sources - singleton (shared instances)
  getIt.registerLazySingleton(() => ApiService());
  getIt.registerLazySingleton(() => LocalDatabase());

  /// Repository - singleton (shared instance)
  getIt.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(
      apiService: getIt(),
      localDatabase: getIt(),
      connectivity: getIt(),
    ),
  );

  /// Cubit - factory (new instance each time)
  /// This allows multiple instances if needed (e.g., for testing)
  getIt.registerFactory(
    () => TaskCubit(
      taskRepository: getIt(),
      connectivity: getIt(),
    ),
  );
}