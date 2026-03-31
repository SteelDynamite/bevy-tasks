import 'package:flutter/material.dart';
import '../rust/api.dart' as api;
import '../theme.dart';

class TaskItem extends StatefulWidget {
  final api.TaskDto task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const TaskItem({super.key, required this.task, required this.onToggle, required this.onTap});

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _hovering = false;
  double _swipeOffset = 0;

  String _formatDueDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final diff = taskDate.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return date.toLocal().toIso8601String().substring(5, 10).replaceAll('-', '/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = widget.task.status == 'completed';
    final canSwipeLeft = !isCompleted;
    final canSwipeRight = isCompleted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () {
          setState(() => _hovering = false);
          widget.onTap();
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            _swipeOffset += details.delta.dx;
            if (canSwipeLeft) _swipeOffset = _swipeOffset.clamp(-150.0, 0.0);
            else if (canSwipeRight) _swipeOffset = _swipeOffset.clamp(0.0, 150.0);
            else _swipeOffset = 0;
          });
        },
        onHorizontalDragEnd: (details) {
          if (_swipeOffset.abs() > 100) widget.onToggle();
          setState(() => _swipeOffset = 0);
        },
        child: Stack(
          children: [
            // Swipe background
            if (_swipeOffset != 0)
              Positioned.fill(
                child: Container(
                  color: AppTheme.primary,
                  alignment: _swipeOffset < 0 ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _swipeOffset < 0 ? 'Complete' : 'Undo',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            // Task content
            Container(
              transform: Matrix4.translationValues(_swipeOffset, 0, 0),
              color: _hovering
                  ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
                  : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox with expanded touch target
                  GestureDetector(
                    onTap: widget.onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? AppTheme.primary : Colors.transparent,
                          border: Border.all(
                            color: isCompleted ? AppTheme.primary : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content column (title, description, due date below)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted
                                ? (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5)
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.task.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.task.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.4),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        // Due date badge (below title/description, matching Tauri)
                        if (widget.task.dueDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                _formatDueDate(widget.task.dueDate!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Chevron (show on hover only)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _hovering ? 0.3 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Icon(Icons.chevron_right, size: 16,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
