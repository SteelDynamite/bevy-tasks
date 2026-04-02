import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onyx_core/onyx_core.dart';
import '../state/app_state.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  String _testStatus = 'idle'; // idle | testing | ok | fail

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final state = context.read<AppState>();
    final wsName = state.config?.currentWorkspace;
    if (wsName == null) return;
    final ws = state.config!.getWorkspace(wsName);
    if (ws?.webdavUrl != null) {
      _urlController.text = ws!.webdavUrl!;
      try {
        final domain = Uri.parse(ws.webdavUrl!).host;
        final creds = state.credentialStore.loadCredentials(domain);
        if (creds != null && mounted) {
          setState(() {
            _userController.text = creds.$1;
            _passController.text = creds.$2;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testStatus = 'testing');
    try {
      final state = context.read<AppState>();
      await state.testWebdavConnection(
        _urlController.text,
        _userController.text,
        _passController.text,
      );
      if (mounted) setState(() => _testStatus = 'ok');
    } catch (_) {
      if (mounted) setState(() => _testStatus = 'fail');
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final wsName = state.config?.currentWorkspace;
    if (wsName == null || _urlController.text.trim().isEmpty) return;
    state.setWebdavConfig(_urlController.text.trim());
    if (_userController.text.isNotEmpty && _passController.text.isNotEmpty) {
      final domain = Uri.parse(_urlController.text.trim()).host;
      state.credentialStore.storeCredentials(
        domain,
        _userController.text,
        _passController.text,
      );
    }
    await state.loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final inputDecoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
    );

    final wsName = state.config?.currentWorkspace;
    final ws = wsName == null ? null : state.config!.getWorkspace(wsName);
    final lastSync = ws?.lastSync;
    String? relTime;
    if (lastSync != null) {
      {
        final secsAgo = DateTime.now().difference(lastSync).inSeconds;
        if (secsAgo < 60) {
          relTime = 'just now';
        } else if (secsAgo < 3600) {
          relTime = '${secsAgo ~/ 60}m ago';
        } else {
          relTime = '${secsAgo ~/ 3600}h ago';
        }
      }
    }

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
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => state.setScreen('tasks'),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.close, size: 20,
                            color: isDark ? AppTheme.textDark : AppTheme.textLight),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // WebDAV section header
                        Text('WEBDAV SYNC',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.5))),
                        const SizedBox(height: 12),
                        // Credentials card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Server URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                              const SizedBox(height: 4),
                              TextField(controller: _urlController, style: const TextStyle(fontSize: 13),
                                decoration: inputDecoration.copyWith(hintText: 'https://dav.example.com/tasks/')),
                              const SizedBox(height: 10),
                              Text('Username', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                              const SizedBox(height: 4),
                              TextField(controller: _userController, style: const TextStyle(fontSize: 13),
                                decoration: inputDecoration),
                              const SizedBox(height: 10),
                              Text('Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                              const SizedBox(height: 4),
                              TextField(controller: _passController, obscureText: true,
                                style: const TextStyle(fontSize: 13), decoration: inputDecoration),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _urlController.text.isEmpty ? null : _testConnection,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: borderColor),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        _testStatus == 'testing' ? 'Testing…'
                                          : _testStatus == 'ok' ? 'Connected'
                                          : _testStatus == 'fail' ? 'Failed — Retry'
                                          : 'Test Connection',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _urlController.text.isEmpty ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Save', style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Sync direction + Sync Now
                        if (wsName != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                                  ),
                                  child: DropdownButton<String>(
                                    value: state.syncMode,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    style: TextStyle(fontSize: 13,
                                      color: isDark ? AppTheme.textDark : AppTheme.textLight),
                                    dropdownColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                                    items: const [
                                      DropdownMenuItem(value: 'full', child: Text('Sync both ways')),
                                      DropdownMenuItem(value: 'push', child: Text('Push only')),
                                      DropdownMenuItem(value: 'pull', child: Text('Pull only')),
                                    ],
                                    onChanged: (v) { if (v != null) state.setSyncMode(v); },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: state.syncing ? null : () => state.triggerSync(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
                                  ),
                                  child: Text(state.syncing ? 'Syncing…' : 'Sync Now',
                                    style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                          if (relTime != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('Last sync: $relTime',
                                  style: TextStyle(fontSize: 11,
                                    color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
                                if (state.lastSyncResult != null) ...[
                                  Text('  ·  ↑${state.lastSyncResult!.uploaded} ↓${state.lastSyncResult!.downloaded}',
                                    style: TextStyle(fontSize: 11,
                                      color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
                                ],
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        // Appearance
                        Text('APPEARANCE',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.5))),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => state.toggleDarkMode(),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Text('Dark mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const Spacer(),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 44, height: 24,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: state.darkMode ? AppTheme.primary : (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 150),
                                    alignment: state.darkMode ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      width: 20, height: 20,
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
                          child: Text('Flutter + Dart',
                            style: TextStyle(fontSize: 12,
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
    );
  }
}
