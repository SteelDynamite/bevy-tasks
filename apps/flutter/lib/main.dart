import 'dart:io' show Platform;
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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  static const _edge = 8.0;
  late final AnimationController _settingsAnim;
  late final Animation<double> _settingsFade;
  late final Animation<double> _settingsScale;
  bool _settingsVisible = false;
  String? _prevScreen;

  @override
  void initState() {
    super.initState();
    _settingsAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _settingsFade = CurvedAnimation(parent: _settingsAnim, curve: Curves.easeOut);
    _settingsScale = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _settingsAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _settingsAnim.dispose();
    super.dispose();
  }

  void _onScreenChanged(String screen) {
    if (screen == 'settings' && _prevScreen != 'settings') {
      _settingsVisible = true;
      _settingsAnim.forward();
    } else if (screen != 'settings' && _prevScreen == 'settings') {
      _settingsAnim.reverse().then((_) {
        if (mounted) setState(() => _settingsVisible = false);
      });
    }
    _prevScreen = screen;
  }

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
    final hasNativeBorder = Platform.isWindows;

    _onScreenChanged(state.screen);

    Widget content = Stack(
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
        if (_settingsVisible)
          FadeTransition(
            opacity: _settingsFade,
            child: ScaleTransition(
              scale: _settingsScale,
              child: const SettingsScreen(),
            ),
          ),
      ],
    );

    if (hasNativeBorder) {
      // Windows provides native border + shadow, just fill with surface color
      return Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        body: ClipRect(child: content),
      );
    }

    // Linux/macOS: custom border, shadow, and resize zones
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(builder: (context, constraints) {
        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          hitTestBehavior: HitTestBehavior.translucent,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (event) {},
            child: Stack(
              children: [
                ..._buildResizeZones(constraints),
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
                    child: content,
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
