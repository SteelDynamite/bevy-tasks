import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _webdavUrlController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPassController = TextEditingController();
  String? _confirmRemove;

  @override
  void dispose() {
    _webdavUrlController.dispose();
    _webdavUserController.dispose();
    _webdavPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => app.setScreen(AppScreen.tasks),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Workspaces section ──
          Text(
            'WORKSPACES',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
          ),
          const SizedBox(height: 12),

          ...app.workspaces.map((ws) {
            final isCurrent = ws.name == app.currentWorkspace;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ws.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: isCurrent ? theme.colorScheme.primary : null,
                                ),
                              ),
                              Text(
                                ws.path,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCurrent)
                          TextButton(
                            onPressed: () => app.switchWorkspace(ws.name),
                            child: const Text('Switch'),
                          ),
                        if (_confirmRemove == ws.name) ...[
                          TextButton(
                            onPressed: () {
                              app.removeWorkspace(ws.name);
                              setState(() => _confirmRemove = null);
                            },
                            child: Text('Confirm', style: TextStyle(color: theme.colorScheme.error)),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _confirmRemove = null),
                            child: const Text('Cancel'),
                          ),
                        ] else
                          TextButton(
                            onPressed: () => setState(() => _confirmRemove = ws.name),
                            child: Text(
                              'Remove',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha(102)),
                            ),
                          ),
                      ],
                    ),
                    if (ws.webdavUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Sync: ${ws.webdavUrl}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(102),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          TextButton.icon(
            onPressed: () => app.setScreen(AppScreen.setup),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add workspace'),
          ),

          const SizedBox(height: 24),

          // ── WebDAV Sync section ──
          Text(
            'WEBDAV SYNC',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Server URL', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _webdavUrlController,
                    decoration: const InputDecoration(hintText: 'https://dav.example.com/tasks/'),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),

                  Text('Username', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  TextField(controller: _webdavUserController),
                  const SizedBox(height: 12),

                  Text('Password', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _webdavPassController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // TODO: test connection
                        },
                        child: const Text('Test Connection'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          // TODO: save webdav config
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (app.currentWorkspace != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(
                onPressed: app.syncing ? null : app.triggerSync,
                child: Text(app.syncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),

          const SizedBox(height: 24),

          // ── Appearance section ──
          Text(
            'APPEARANCE',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: SwitchListTile(
              title: const Text('Dark mode'),
              value: app.darkMode,
              onChanged: (_) => app.toggleDarkMode(),
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Flutter + flutter_rust_bridge',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(77),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
