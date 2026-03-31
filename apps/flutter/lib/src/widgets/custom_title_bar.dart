import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme.dart';

class CustomTitleBar extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final bool centerTitle;
  final List<Widget>? actions;
  final bool showClose;

  const CustomTitleBar({super.key, this.leading, this.title, this.centerTitle = false, this.actions, this.showClose = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
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
            if (leading != null) leading!,
            if (title != null)
              Expanded(
                child: centerTitle
                    ? Center(
                        child: Text(
                          title!,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Text(
                        title!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
              )
            else
              const Expanded(child: SizedBox.shrink()),
            if (actions != null) ...actions!,
            if (showClose) ...[
              const SizedBox(width: 4),
              _TitleBarButton(
                icon: Icons.close,
                onPressed: () => windowManager.close(),
                hoverColor: AppTheme.danger,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;

  const _TitleBarButton({required this.icon, required this.onPressed, required this.hoverColor});

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovering ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 14,
            color: _hovering ? widget.hoverColor : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
