import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_manager/core/di_container.dart';
import 'package:task_manager/presentation/cubits/task_cubit.dart';
import 'package:task_manager/presentation/pages/home_page.dart';
import 'package:task_manager/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<TaskCubit>(),
      child: MaterialApp(
        title: 'Task Manager',
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const LoginPage(),
      ),
    );
  }
}