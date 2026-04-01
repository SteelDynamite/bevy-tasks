import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../rust/api.dart' as api;
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/task_item.dart';
import '../widgets/task_detail_view.dart';
import '../widgets/new_task_input.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  bool _drawerOpen = false;
  bool _showCompleted = false;
  bool _completedVisible = false;
  bool _addingList = false;
  bool _workspaceSwitcherOpen = false;
  bool _newTaskOpen = false;
  final _newListController = TextEditingController();
  final _newListFocus = FocusNode();
  late final AnimationController _newTaskAnim;
  late final Animation<Offset> _newTaskSlide;
  late final Animation<double> _newTaskFade;

  @override
  void initState() {
    super.initState();
    _newTaskAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _newTaskSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _newTaskAnim, curve: Curves.easeOut));
    _newTaskFade = CurvedAnimation(parent: _newTaskAnim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _newTaskAnim.dispose();
    _newListController.dispose();
    _newListFocus.dispose();
    super.dispose();
  }

  void _toggleDrawer() => setState(() {
    _drawerOpen = !_drawerOpen;
    if (!_drawerOpen) _workspaceSwitcherOpen = false;
  });

  void _closeDrawer() => setState(() {
    _drawerOpen = false;
    _workspaceSwitcherOpen = false;
    _addingList = false;
  });

  void _showNewTask() {
    final state = context.read<AppState>();
    if (state.activeListId == null) return;
    setState(() => _newTaskOpen = true);
    _newTaskAnim.forward();
  }

  void _closeNewTask() {
    _newTaskAnim.reverse().then((_) {
      if (mounted) setState(() => _newTaskOpen = false);
    });
  }

  Future<void> _handleCreateTask(String title, String desc, {String? dueDate, bool hasTime = false}) async {
    final state = context.read<AppState>();
    final task = await state.createTask(title, desc);
    if (task != null && dueDate != null) {
      await state.updateTask(api.TaskDto(
        id: task.id, title: task.title, description: task.description,
        status: task.status, dueDate: dueDate, hasTime: hasTime,
        createdAt: task.createdAt, updatedAt: task.updatedAt, parentId: task.parentId,
      ));
    }
    _closeNewTask();
  }

  void _startAddingList() {
    setState(() {
      _addingList = true;
      _newListController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _newListFocus.requestFocus());
  }

  Future<void> _submitNewList() async {
    final name = _newListController.text.trim();
    if (name.isNotEmpty) await context.read<AppState>().createList(name);
    setState(() => _addingList = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final drawerWidth = width * 0.8;
      final hasDetail = state.selectedTask != null;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Sliding container: drawer + main + detail
          Positioned.fill(
            child: ClipRect(
              child: OverflowBox(
                maxWidth: drawerWidth + width,
                alignment: Alignment.centerLeft,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  offset: _drawerOpen ? Offset.zero : Offset(-drawerWidth / (drawerWidth + width), 0),
                  child: SizedBox(
                    width: drawerWidth + width,
                    child: Row(
                      children: [
                        SizedBox(width: drawerWidth, child: _buildDrawer(state, isDark)),
                        SizedBox(
                          width: width,
                          child: _buildMainWithDetail(state, isDark, width),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // FAB button (centered, 56px, hidden when drawer/detail/newTask open)
          if (!_drawerOpen && !hasDetail && !_newTaskOpen && state.activeListId != null)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    onPressed: _showNewTask,
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add, size: 28),
                  ),
                ),
              ),
            ),
          // New task overlay (animated, inside app bounds)
          if (_newTaskOpen || _newTaskAnim.isAnimating)
            Positioned.fill(
              child: FadeTransition(
                opacity: _newTaskFade,
                child: GestureDetector(
                  onTap: _closeNewTask,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {},
                      child: SlideTransition(
                        position: _newTaskSlide,
                        child: NewTaskInput(onCreate: _handleCreateTask),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildMainWithDetail(AppState state, bool isDark, double totalWidth) {
    final hasDetail = state.selectedTask != null;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        ClipRect(
          child: OverflowBox(
            maxWidth: totalWidth * 2,
            alignment: Alignment.centerLeft,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              offset: hasDetail ? const Offset(-0.5, 0) : Offset.zero,
              child: SizedBox(
                width: totalWidth * 2,
                child: Row(
                  children: [
                    SizedBox(width: totalWidth, child: _buildMain(state, isDark)),
                    SizedBox(
                      width: totalWidth,
                      child: Container(
                        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                        child: hasDetail
                            ? TaskDetailView(task: state.selectedTask!)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Drawer shadow (narrow element at left edge casting right)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 1,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              opacity: _drawerOpen ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(4, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Dim overlay when drawer is open
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_drawerOpen,
            child: GestureDetector(
              onTap: _closeDrawer,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                opacity: _drawerOpen ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        // Sync status indicator
        Positioned(
          bottom: 16,
          right: 16,
          child: IgnorePointer(
            child: state.syncing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary))
                : state.lastSyncResult != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '↑${state.lastSyncResult!.uploaded} ↓${state.lastSyncResult!.downloaded}',
                          style: TextStyle(fontSize: 11,
                            color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.6)),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(AppState state, bool isDark) {
    return Container(
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      child: Stack(
        children: [
          Column(
            children: [
              // Header: workspace switcher
              GestureDetector(
                onPanStart: (_) {},
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _workspaceSwitcherOpen = !_workspaceSwitcherOpen),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    state.config?.currentWorkspace ?? 'Workspace',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedRotation(
                                  turns: _workspaceSwitcherOpen ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Icon(Icons.expand_more, size: 14,
                                    color: isDark ? AppTheme.textDark : AppTheme.textLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // List items
              Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final list in state.lists)
                  _ListTile(
                    list: list,
                    isActive: list.id == state.activeListId,
                    onTap: () {
                      state.selectList(list.id);
                      _closeDrawer();
                    },
                    onDelete: () => state.deleteList(list.id),
                    onRename: (newName) => state.renameList(list.id, newName),
                    onToggleGroupByDueDate: () => state.setGroupByDueDate(list.id, !list.groupByDueDate),
                  ),
                // New list button / input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: _addingList
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newListController,
                                focusNode: _newListFocus,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'List name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppTheme.primary),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _submitNewList(),
                                onTapOutside: (_) => setState(() => _addingList = false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _submitNewList,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Add', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: _startAddingList,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text('+ New list', style: TextStyle(fontSize: 14, color: AppTheme.primary)),
                        ),
                      ),
                ),
              ],
            ),
          ),
            // Footer: Settings button (matching Tauri)
            GestureDetector(
              onTap: () => state.setScreen('settings'),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18,
                      color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text('Settings', style: TextStyle(fontSize: 14,
                      color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ),
          ],
          ),
          // Workspace switcher popup backdrop
          if (_workspaceSwitcherOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _workspaceSwitcherOpen = false),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          // Workspace switcher popup menu
          Positioned(
            left: 8,
            right: 8,
            top: 48,
            child: AnimatedScale(
              scale: _workspaceSwitcherOpen ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: AnimatedOpacity(
                opacity: _workspaceSwitcherOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !_workspaceSwitcherOpen,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: state.config != null
                      ? ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            for (final ws in state.config!.workspaces)
                              _WorkspaceMenuItem(
                                name: ws.name,
                                path: ws.path,
                                isActive: ws.name == state.config?.currentWorkspace,
                                onTap: () {
                                  state.switchWorkspace(ws.name);
                                  setState(() => _workspaceSwitcherOpen = false);
                                },
                              ),
                            // Add workspace
                            _WorkspaceMenuItem(
                              icon: null,
                              name: '+ Add workspace',
                              path: null,
                              isActive: false,
                              isAccent: true,
                              showDivider: true,
                              onTap: () {
                                setState(() => _workspaceSwitcherOpen = false);
                                state.setScreen('setup');
                              },
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMain(AppState state, bool isDark) {
    return Column(
      children: [
        // Title bar with menu button + centered title + close
        CustomTitleBar(
          leading: GestureDetector(
            onTap: _toggleDrawer,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.menu, size: 20,
                color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.6)),
            ),
          ),
          title: state.activeList?.title ?? 'Tasks',
          centerTitle: true,
        ),
        // Task list
        Expanded(
          child: state.lists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('No lists yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
                        color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.6))),
                      const SizedBox(height: 4),
                      Text('Tap the list name above to create one', style: TextStyle(fontSize: 14,
                        color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
                    ],
                  ),
                )
              : state.activeList == null
                  ? Center(
                      child: Text('Select a list', style: TextStyle(
                        color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
                    )
                  : _buildTaskList(state, isDark),
        ),
      ],
    );
  }

  Widget _buildTaskList(AppState state, bool isDark) {
    if (state.pendingTasks.isEmpty && state.completedTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No tasks. Add one below.', style: TextStyle(fontSize: 14,
            color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4))),
        ),
      );
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final task = state.pendingTasks[oldIndex];
        state.reorderTask(task.id, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            child: child,
          ),
          child: child,
        );
      },
      footer: _buildCompletedSection(state, isDark),
      children: [
        for (var i = 0; i < state.pendingTasks.length; i++)
          ReorderableDragStartListener(
            key: ValueKey(state.pendingTasks[i].id),
            index: i,
            child: TaskItem(
              task: state.pendingTasks[i],
              onToggle: () => state.toggleTask(state.pendingTasks[i].id),
              onTap: () => state.selectTask(state.pendingTasks[i].id),
            ),
          ),
      ],
    );
  }

  Widget? _buildCompletedSection(AppState state, bool isDark) {
    if (state.completedTasks.isEmpty) return null;
    return Column(
      children: [
        const SizedBox(height: 16),
        // Completed header (matching Tauri: full-width, border-top, text left, chevron right)
        GestureDetector(
          onTap: () {
            setState(() {
              if (_showCompleted) {
                _showCompleted = false;
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted) setState(() => _completedVisible = false);
                });
              } else {
                _completedVisible = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _showCompleted = true);
                });
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              border: Border(top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Completed (${state.completedTasks.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _showCompleted ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.chevron_right, size: 16,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                ),
              ],
            ),
          ),
        ),
        if (_completedVisible)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _showCompleted ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 150),
              offset: _showCompleted ? Offset.zero : const Offset(0, -0.05),
              child: Column(
                children: [
                  for (final task in state.completedTasks)
                    TaskItem(
                      task: task,
                      onToggle: () => state.toggleTask(task.id),
                      onTap: () => state.selectTask(task.id),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ListTile extends StatefulWidget {
  final dynamic list;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(String newName) onRename;
  final VoidCallback onToggleGroupByDueDate;

  const _ListTile({required this.list, required this.isActive, required this.onTap, required this.onDelete, required this.onRename, required this.onToggleGroupByDueDate});

  @override
  State<_ListTile> createState() => _ListTileState();
}

class _ListTileState extends State<_ListTile> {
  bool _hovering = false;

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.list.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
          onSubmitted: (value) {
            Navigator.pop(ctx);
            if (value.trim().isNotEmpty && value.trim() != widget.list.title) {
              widget.onRename(value.trim());
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final name = controller.text.trim();
              if (name.isNotEmpty && name != widget.list.title) widget.onRename(name);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) {
          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
            items: [
              PopupMenuItem(
                onTap: () => _showRenameDialog(context),
                child: const Text('Rename', style: TextStyle(fontSize: 13)),
              ),
              PopupMenuItem(
                onTap: widget.onToggleGroupByDueDate,
                child: Row(
                  children: [
                    Expanded(child: Text('Group by due date', style: const TextStyle(fontSize: 13))),
                    if (widget.list.groupByDueDate)
                      const Icon(Icons.check, size: 16, color: AppTheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: widget.onDelete,
                child: const Text('Delete', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
              ),
            ],
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: _hovering && !widget.isActive
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (widget.isActive)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.check, size: 16,
                    color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5)),
                ),
              Expanded(
                child: Text(
                  widget.list.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceMenuItem extends StatefulWidget {
  final String name;
  final String? path;
  final bool isActive;
  final bool isAccent;
  final bool showDivider;
  final IconData? icon;
  final VoidCallback onTap;

  const _WorkspaceMenuItem({
    required this.name,
    this.path,
    required this.isActive,
    this.isAccent = false,
    this.showDivider = false,
    this.icon,
    required this.onTap,
  });

  @override
  State<_WorkspaceMenuItem> createState() => _WorkspaceMenuItemState();
}

class _WorkspaceMenuItemState extends State<_WorkspaceMenuItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDivider)
          Divider(height: 1, thickness: 0.5, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              color: _hovering
                  ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  if (widget.isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.check, size: 16,
                        color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5)),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.normal,
                            color: widget.isAccent ? AppTheme.primary : null,
                          ),
                          overflow: TextOverflow.ellipsis),
                        if (widget.path != null)
                          Text(widget.path!,
                            style: TextStyle(fontSize: 12,
                              color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.4)),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
