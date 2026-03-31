import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'src/rust/frb_generated.dart';
import 'src/theme.dart';
import 'src/state/app_state.dart';
import 'src/screens/setup_screen.dart';
import 'src/screens/tasks_screen.dart';
import 'src/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(400, 700),
      minimumSize: Size(320, 500),
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setResizable(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..loadConfig(),
      child: const BevyTasksApp(),
    ),
  );
}

class BevyTasksApp extends StatelessWidget {
  const BevyTasksApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Bevy Tasks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _edge = 8.0;

  SystemMouseCursor _cursorFor(ResizeEdge? edge) => switch (edge) {
    ResizeEdge.top || ResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
    ResizeEdge.left || ResizeEdge.right => SystemMouseCursors.resizeLeftRight,
    ResizeEdge.topLeft || ResizeEdge.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    ResizeEdge.topRight || ResizeEdge.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
    _ => SystemMouseCursors.basic,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(builder: (context, constraints) {
        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          hitTestBehavior: HitTestBehavior.translucent,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (event) {
              // Update cursor based on edge proximity (handled by nested MouseRegion below)
            },
            child: Stack(
              children: [
                // Resize hit zones (in the 8px padding area)
                ..._buildResizeZones(constraints),
                // Main content with padding
                Padding(
                  padding: const EdgeInsets.all(_edge),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (state.screen == 'setup')
                          const SetupScreen()
                        else
                          const TasksScreen(),
                        if (state.error != null)
                          Positioned(
                            top: 0, left: 0, right: 0,
                            child: Material(
                              color: AppTheme.danger,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(state.error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    ),
                                    GestureDetector(
                                      onTap: state.clearError,
                                      child: const Text('✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (state.screen == 'settings')
                          const SettingsScreen(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildResizeZones(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    Widget zone(ResizeEdge edge, {required double left, required double top, required double width, required double height}) {
      return Positioned(
        left: left, top: top, width: width, height: height,
        child: MouseRegion(
          cursor: _cursorFor(edge),
          child: GestureDetector(
            onPanStart: (_) => windowManager.startResizing(edge),
          ),
        ),
      );
    }
    return [
      // Corners (larger hit area)
      zone(ResizeEdge.topLeft, left: 0, top: 0, width: _edge * 2, height: _edge * 2),
      zone(ResizeEdge.topRight, left: w - _edge * 2, top: 0, width: _edge * 2, height: _edge * 2),
      zone(ResizeEdge.bottomLeft, left: 0, top: h - _edge * 2, width: _edge * 2, height: _edge * 2),
      zone(ResizeEdge.bottomRight, left: w - _edge * 2, top: h - _edge * 2, width: _edge * 2, height: _edge * 2),
      // Edges
      zone(ResizeEdge.top, left: _edge * 2, top: 0, width: w - _edge * 4, height: _edge),
      zone(ResizeEdge.bottom, left: _edge * 2, top: h - _edge, width: w - _edge * 4, height: _edge),
      zone(ResizeEdge.left, left: 0, top: _edge * 2, width: _edge, height: h - _edge * 4),
      zone(ResizeEdge.right, left: w - _edge, top: _edge * 2, width: _edge, height: h - _edge * 4),
    ];
  }
}
