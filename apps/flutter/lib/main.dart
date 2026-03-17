import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/setup_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/settings_screen.dart';
import 'src/rust/frb_generated.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const BevyTasksApp());
}

class BevyTasksApp extends StatelessWidget {
  const BevyTasksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          return MaterialApp(
            title: 'Bevy Tasks',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: app.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: _buildScreen(app),
          );
        },
      ),
    );
  }

  Widget _buildScreen(AppProvider app) {
    switch (app.screen) {
      case AppScreen.setup:
        return const SetupScreen();
      case AppScreen.tasks:
        return const TasksScreen();
      case AppScreen.settings:
        return const SettingsScreen();
    }
  }
}
