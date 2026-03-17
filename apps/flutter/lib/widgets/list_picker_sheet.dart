import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ListPickerSheet extends StatefulWidget {
  const ListPickerSheet({super.key});

  @override
  State<ListPickerSheet> createState() => _ListPickerSheetState();
}

class _ListPickerSheetState extends State<ListPickerSheet> {
  bool _showNewList = false;
  final _newListController = TextEditingController();
  String? _confirmDelete;

  @override
  void dispose() {
    _newListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: theme.dividerColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Lists', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ...app.lists.map((list) {
            final isActive = list.id == app.activeListId;
            return ListTile(
              dense: true,
              title: Text(
                list.title,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : null,
                  color: isActive ? theme.colorScheme.primary : null,
                ),
              ),
              trailing: _confirmDelete == list.id
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            app.deleteList(list.id);
                            setState(() => _confirmDelete = null);
                          },
                          child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _confirmDelete = null),
                          child: const Text('Cancel'),
                        ),
                      ],
                    )
                  : IconButton(
                      onPressed: () => setState(() => _confirmDelete = list.id),
                      icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.onSurfaceVariant.withAlpha(77)),
                    ),
              onTap: () {
                app.selectList(list.id);
                Navigator.pop(context);
              },
            );
          }),

          if (_showNewList)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newListController,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'List name'),
                      onSubmitted: (_) => _createList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _createList,
                    child: const Text('Add'),
                  ),
                ],
              ),
            )
          else
            TextButton.icon(
              onPressed: () => setState(() => _showNewList = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New list'),
            ),
        ],
      ),
    );
  }

  void _createList() {
    final name = _newListController.text.trim();
    if (name.isEmpty) return;
    context.read<AppProvider>().createList(name);
    _newListController.clear();
    setState(() => _showNewList = false);
    Navigator.pop(context);
  }
}
