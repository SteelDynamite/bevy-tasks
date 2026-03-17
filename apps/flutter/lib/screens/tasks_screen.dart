import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/task_item.dart';
import '../widgets/new_task_bar.dart';
import '../widgets/list_picker_sheet.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showCompleted = true;

  void _openListPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const ListPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openListPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  app.activeList?.title ?? 'Tasks',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          if (app.syncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: app.toggleDarkMode,
            icon: Icon(app.darkMode ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            onPressed: () => app.setScreen(AppScreen.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (app.error != null)
            MaterialBanner(
              content: Text(app.error!, style: const TextStyle(fontSize: 13)),
              backgroundColor: theme.colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: app.clearError,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: app.lists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No lists yet', style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                        const SizedBox(height: 4),
                        Text('Tap the title to create one', style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                        )),
                      ],
                    ),
                  )
                : app.activeListId == null
                    ? Center(
                        child: Text('Select a list', style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          ...app.pendingTasks.map((task) => TaskItem(task: task)),
                          if (app.pendingTasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No tasks. Add one below.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant.withAlpha(102),
                                  ),
                                ),
                              ),
                            ),
                          if (app.completedTasks.isNotEmpty) ...[
                            const Divider(),
                            ListTile(
                              dense: true,
                              leading: Icon(
                                _showCompleted ? Icons.expand_more : Icons.chevron_right,
                                size: 20,
                              ),
                              title: Text(
                                'Completed (${app.completedTasks.length})',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () => setState(() => _showCompleted = !_showCompleted),
                            ),
                            if (_showCompleted)
                              ...app.completedTasks.map((task) => TaskItem(task: task)),
                          ],
                        ],
                      ),
          ),
          const NewTaskBar(),
        ],
      ),
    );
  }
}
