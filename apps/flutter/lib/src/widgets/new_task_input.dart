import 'package:flutter/material.dart';
import '../theme.dart';
import 'date_time_picker.dart';

class NewTaskInput extends StatefulWidget {
  final Future<void> Function(String title, String description, {String? dueDate, bool hasTime}) onCreate;

  const NewTaskInput({super.key, required this.onCreate});

  @override
  State<NewTaskInput> createState() => _NewTaskInputState();
}

class _NewTaskInputState extends State<NewTaskInput> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _titleFocus = FocusNode();
  DateTime? _selectedDate;
  bool _selectedHasTime = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await widget.onCreate(title, _descController.text.trim(), dueDate: _selectedDate?.toUtc().toIso8601String(), hasTime: _selectedHasTime);
  }

  void _pickDate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DateTimePicker(
        initialDate: _selectedDate,
        initialHasTime: _selectedHasTime,
        onDone: (date, hasTime) => setState(() { _selectedDate = date; _selectedHasTime = hasTime; }),
        onClear: () => setState(() { _selectedDate = null; _selectedHasTime = false; }),
      ),
    );
  }

  String _formatDateChip(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(d.year, d.month, d.day);
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final day = dayNames[d.weekday % 7];
    final pad = (int n) => n.toString().padLeft(2, '0');
    final timePart = _selectedHasTime ? ', ${pad(d.hour)}:${pad(d.minute)}' : '';
    if (taskDate == today) return 'Today$timePart';
    return '$day, ${pad(d.day)}/${pad(d.month)}$timePart';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title input
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Task title',
                hintStyle: TextStyle(
                  color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.3)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            // Description with icon (matching Tauri)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.subject, size: 20,
                    color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _descController,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add details',
                      hintStyle: TextStyle(
                        color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date/time with icon (matching Tauri)
            Row(
              children: [
                Icon(Icons.access_time, size: 20,
                  color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                if (_selectedDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _pickDate,
                          child: Text(
                            _formatDateChip(_selectedDate!),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedDate = null),
                          child: Icon(Icons.close, size: 14,
                            color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _pickDate,
                    child: Text('Add date/time', style: TextStyle(fontSize: 14,
                      color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Save button (centered, matching Tauri)
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _submit,
                  child: Text('Save',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _titleController.text.trim().isNotEmpty
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
