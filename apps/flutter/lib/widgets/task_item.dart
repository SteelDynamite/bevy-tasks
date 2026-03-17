import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/rust/api.dart' as api;
import '../providers/app_provider.dart';

class TaskItem extends StatelessWidget {
  final api.BridgeTask task;

  const TaskItem({super.key, required this.task});

  bool get _isCompleted => task.status == 'completed';

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(d.year, d.month, d.day);

    if (taskDate == today) return 'Today';
    if (taskDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(task.id),
      direction: _isCompleted ? DismissDirection.startToEnd : DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.primary,
        alignment: _isCompleted ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          _isCompleted ? 'Undo' : 'Complete',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
      confirmDismiss: (_) async {
        await app.toggleTask(task.id);
        return false; // Don't remove widget — loadTasks handles the rebuild
      },
      child: InkWell(
        onTap: () => _showEditSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => app.toggleTask(task.id),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isCompleted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withAlpha(102),
                      width: 2,
                    ),
                    color: _isCompleted ? theme.colorScheme.primary : null,
                  ),
                  child: _isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: _isCompleted ? null : FontWeight.w500,
                        decoration: _isCompleted ? TextDecoration.lineThrough : null,
                        color: _isCompleted
                            ? theme.colorScheme.onSurfaceVariant.withAlpha(128)
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(102),
                          ),
                        ),
                      ),
                    if (task.dueDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.dividerTheme.color ?? theme.dividerColor,
                            ),
                          ),
                          child: Text(
                            _formatDate(task.dueDate!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                onPressed: () => app.deleteTask(task.id),
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final app = context.read<AppProvider>();
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(ctx).dividerColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                enabled: !_isCompleted,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                enabled: !_isCompleted,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isCompleted
                        ? null
                        : () {
                            app.updateTask(task.id, titleController.text.trim(), descController.text);
                            Navigator.pop(ctx);
                          },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
