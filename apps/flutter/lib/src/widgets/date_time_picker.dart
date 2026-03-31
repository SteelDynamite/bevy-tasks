import 'package:flutter/material.dart';
import '../theme.dart';

class DateTimePicker extends StatefulWidget {
  final DateTime? initialDate;
  final void Function(DateTime date) onDone;
  final VoidCallback onClear;

  const DateTimePicker({super.key, this.initialDate, required this.onDone, required this.onClear});

  @override
  State<DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  late DateTime _viewMonth;
  DateTime? _selected;
  bool _showTime = false;
  int _hour = 12;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _viewMonth = widget.initialDate ?? DateTime.now();
    if (widget.initialDate != null) {
      _hour = widget.initialDate!.hour;
      _minute = widget.initialDate!.minute;
      _showTime = _hour != 0 || _minute != 0;
    }
  }

  void _prevMonth() => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1));
  void _nextMonth() => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1));

  void _done() {
    if (_selected == null) return;
    final result = _showTime
        ? DateTime(_selected!.year, _selected!.month, _selected!.day, _hour, _minute)
        : DateTime(_selected!.year, _selected!.month, _selected!.day);
    widget.onDone(result);
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.onClear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon
    const dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Text('Date & Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _done,
                child: const Text('Done', style: TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Month navigation
          Row(
            children: [
              GestureDetector(onTap: _prevMonth, child: const Icon(Icons.chevron_left, size: 20)),
              Expanded(
                child: Center(
                  child: Text('${months[_viewMonth.month - 1]} ${_viewMonth.year}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
              GestureDetector(onTap: _nextMonth, child: const Icon(Icons.chevron_right, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          // Day names
          Row(
            children: [
              for (final name in dayNames)
                Expanded(
                  child: Center(
                    child: Text(name, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Calendar grid
          ...List.generate(6, (week) {
            return Row(
              children: List.generate(7, (dow) {
                final dayIndex = week * 7 + dow - (startWeekday - 1);
                if (dayIndex < 0 || dayIndex >= lastDay.day) return const Expanded(child: SizedBox(height: 32));
                final day = dayIndex + 1;
                final date = DateTime(_viewMonth.year, _viewMonth.month, day);
                final isToday = date == today;
                final isSelected = _selected != null && date.year == _selected!.year && date.month == _selected!.month && date.day == _selected!.day;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = date),
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppTheme.primary : Colors.transparent,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                          color: isSelected ? Colors.white : (isToday ? AppTheme.primary : null),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 8),
          // Time toggle
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showTime = !_showTime),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                      const SizedBox(width: 8),
                      Text(_showTime ? 'Time' : 'Set time',
                        style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                      const Spacer(),
                      Icon(_showTime ? Icons.expand_less : Icons.expand_more, size: 18,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                    ],
                  ),
                ),
                if (_showTime) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hour
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<int>(
                          value: _hour,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textDark : AppTheme.textLight),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                          onChanged: (v) => setState(() => _hour = v!),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                      // Minute
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<int>(
                          value: _minute,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textDark : AppTheme.textLight),
                          items: List.generate(12, (i) => i * 5).map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))).toList(),
                          onChanged: (v) => setState(() => _minute = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Clear button
          if (widget.initialDate != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _clear,
              child: const Text('Clear date', style: TextStyle(fontSize: 13, color: AppTheme.danger)),
            ),
          ],
        ],
      ),
    );
  }
}
