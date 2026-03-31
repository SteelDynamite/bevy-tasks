import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => state.setScreen('tasks'),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.04,
          vertical: MediaQuery.of(context).size.height * 0.04,
        ),
        child: GestureDetector(
          onTap: () {},
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 60, offset: const Offset(0, 25)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Header (matching Tauri: text-lg font-bold, border-b, px-4 py-3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => state.setScreen('tasks'),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close, size: 20,
                              color: isDark ? AppTheme.textDark : AppTheme.textLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // WebDAV Sync section (matching Tauri order: sync first)
                          Text('WEBDAV SYNC',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.5),
                            )),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                            ),
                            child: Text(
                              'WebDAV sync not yet available in Flutter build',
                              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Appearance section
                          Text('APPEARANCE',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.5),
                            )),
                          const SizedBox(height: 12),
                          // Dark mode toggle in bordered card (matching Tauri)
                          GestureDetector(
                            onTap: () => state.toggleDarkMode(),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                              ),
                              child: Row(
                                children: [
                                  const Text('Dark mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  // Toggle switch (matching Tauri: h-6 w-11)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 44,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: state.darkMode ? AppTheme.primary : (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(milliseconds: 200),
                                      alignment: state.darkMode ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        margin: const EdgeInsets.symmetric(horizontal: 2),
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: Text('Flutter + Rust', style: TextStyle(fontSize: 12,
                              color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.3))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
