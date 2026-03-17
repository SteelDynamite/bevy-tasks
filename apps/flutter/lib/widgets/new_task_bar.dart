import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class NewTaskBar extends StatefulWidget {
  const NewTaskBar({super.key});

  @override
  State<NewTaskBar> createState() => _NewTaskBarState();
}

class _NewTaskBarState extends State<NewTaskBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    context.read<AppProvider>().createTask(title);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerTheme.color ?? theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: app.activeListId != null,
              decoration: InputDecoration(
                hintText: app.activeListId != null ? 'Add a task...' : 'Select a list first',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _submit,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
