import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../rust/api.dart' as api;
import '../state/app_state.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import 'date_time_picker.dart';

class TaskDetailView extends StatefulWidget {
  final api.TaskDto task;

  const TaskDetailView({super.key, required this.task});

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  Timer? _debounce;
  bool _showMenu = false;
  late final AnimationController _menuAnim;
  late final Animation<double> _menuFade;
  late final Animation<double> _menuScale;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _menuAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _menuFade = CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut);
    _menuScale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(TaskDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _titleController.text = widget.task.title;
      _descController.text = widget.task.description;
      _showMenu = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _menuAnim.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _scheduleUpdate({String? dueDate}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final state = context.read<AppState>();
      state.updateTask(api.TaskDto(
        id: widget.task.id,
        title: _titleController.text,
        description: _descController.text,
        status: widget.task.status,
        dueDate: dueDate ?? widget.task.dueDate,
        createdAt: widget.task.createdAt,
        updatedAt: widget.task.updatedAt,
        parentId: widget.task.parentId,
      ));
    });
  }

  void _updateDueDate(String? dueDate) {
    final state = context.read<AppState>();
    state.updateTask(api.TaskDto(
      id: widget.task.id,
      title: _titleController.text,
      description: _descController.text,
      status: widget.task.status,
      dueDate: dueDate,
      createdAt: widget.task.createdAt,
      updatedAt: widget.task.updatedAt,
      parentId: widget.task.parentId,
    ));
  }

  void _editDate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DateTimePicker(
        initialDate: widget.task.dueDate != null ? DateTime.tryParse(widget.task.dueDate!) : null,
        onDone: (date) => _updateDueDate(date.toUtc().toIso8601String()),
        onClear: () => _updateDueDate(null),
      ),
    );
  }

  String _formatDateChip(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(local.year, local.month, local.day);
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final day = dayNames[local.weekday % 7];
    final pad = (int n) => n.toString().padLeft(2, '0');
    final hasTime = local.hour != 0 || local.minute != 0;
    final timePart = hasTime ? ', ${pad(local.hour)}:${pad(local.minute)}' : '';
    if (taskDate == today) return 'Today$timePart';
    return '$day, ${pad(local.day)}/${pad(local.month)}$timePart';
  }

  void _showMoveToSheet(BuildContext context, AppState state) {
    final otherLists = state.lists.where((l) => l.id != state.activeListId).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Move to...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final list in otherLists)
              ListTile(
                title: Text(list.title, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  state.moveTask(widget.task.id, list.id);
                  state.selectTask(null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.read<AppState>();
    final isCompleted = widget.task.status == 'completed';
    return Column(
      children: [
        // Header (just back button, matching Tauri)
        GestureDetector(
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => state.selectTask(null),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back, size: 20,
                      color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Task title',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => _scheduleUpdate(),
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
                            maxLines: null,
                            minLines: 3,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Add details',
                              hintStyle: TextStyle(
                                color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => _scheduleUpdate(),
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
                        if (widget.task.dueDate != null)
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
                                  onTap: _editDate,
                                  child: Text(
                                    _formatDateChip(widget.task.dueDate!),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _updateDueDate(null),
                                  child: Icon(Icons.close, size: 14,
                                    color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _editDate,
                            child: Text('Add date/time', style: TextStyle(fontSize: 14,
                              color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Click-off backdrop to close kebab menu
              if (_showMenu)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      _menuAnim.reverse().then((_) {
                        if (mounted) setState(() => _showMenu = false);
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              // Kebab menu (absolute positioned in content, matching Tauri)
              Positioned(
                right: 12,
                top: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _showMenu = !_showMenu);
                        if (_showMenu) _menuAnim.forward(); else _menuAnim.reverse();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.more_vert, size: 20,
                          color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5)),
                      ),
                    ),
                    ScaleTransition(
                      scale: _menuScale,
                      alignment: Alignment.topRight,
                      child: FadeTransition(
                        opacity: _menuFade,
                        child: IgnorePointer(
                          ignoring: !_showMenu,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _KebabMenuItem(
                                    icon: isCompleted ? Icons.close : Icons.check,
                                    label: isCompleted ? 'Restore task' : 'Mark as completed',
                                    onTap: () {
                                      setState(() => _showMenu = false);
                                      state.toggleTask(widget.task.id);
                                      state.selectTask(null);
                                    },
                                  ),
                                  if (state.lists.where((l) => l.id != state.activeListId).isNotEmpty)
                                    _KebabMenuItem(
                                      icon: Icons.drive_file_move_outline,
                                      label: 'Move to...',
                                      onTap: () {
                                        setState(() => _showMenu = false);
                                        _showMoveToSheet(context, state);
                                      },
                                    ),
                                  _KebabMenuItem(
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    color: AppTheme.danger,
                                    onTap: () {
                                      setState(() => _showMenu = false);
                                      state.deleteTask(widget.task.id);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KebabMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _KebabMenuItem({required this.icon, required this.label, this.color, required this.onTap});

  @override
  State<_KebabMenuItem> createState() => _KebabMenuItemState();
}

class _KebabMenuItemState extends State<_KebabMenuItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovering
              ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 8),
              Text(widget.label, style: TextStyle(color: widget.color, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
