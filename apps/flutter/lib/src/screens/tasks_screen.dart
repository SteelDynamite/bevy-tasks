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

class _TasksScreenState extends State<TasksScreen> {
  bool _drawerOpen = false;
  bool _showCompleted = false;
  bool _completedVisible = false;
  bool _addingList = false;
  bool _workspaceSwitcherOpen = false;
  bool _newTaskOpen = false;
  final _newListController = TextEditingController();
  final _newListFocus = FocusNode();

  @override
  void dispose() {
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
  }

  void _closeNewTask() {
    setState(() => _newTaskOpen = false);
  }

  Future<void> _handleCreateTask(String title, String desc, {String? dueDate}) async {
    final state = context.read<AppState>();
    final task = await state.createTask(title, desc);
    if (task != null && dueDate != null) {
      await state.updateTask(api.TaskDto(
        id: task.id, title: task.title, description: task.description,
        status: task.status, dueDate: dueDate,
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: _drawerOpen ? 0.0 : -drawerWidth,
            top: 0,
            bottom: 0,
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
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_newTaskOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                opacity: _newTaskOpen ? 1.0 : 0.0,
                child: GestureDetector(
                  onTap: _closeNewTask,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {},
                      child: _newTaskOpen
                          ? NewTaskInput(onCreate: _handleCreateTask)
                          : const SizedBox.shrink(),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(hasDetail ? -totalWidth : 0, 0, 0),
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
        // Dim overlay when drawer is open (animated fade)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_drawerOpen,
            child: GestureDetector(
              onTap: _closeDrawer,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                opacity: _drawerOpen ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(8, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(AppState state, bool isDark) {
    return Container(
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      child: Column(
        children: [
          // Header: workspace switcher (matching Tauri)
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
                              duration: const Duration(milliseconds: 200),
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
          // Workspace dropdown (appears below header)
          if (_workspaceSwitcherOpen && state.config != null)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                border: Border(
                  bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final ws in state.config!.workspaces)
                    GestureDetector(
                      onTap: () {
                        state.switchWorkspace(ws.name);
                        setState(() => _workspaceSwitcherOpen = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              if (ws.name == state.config?.currentWorkspace)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.check, size: 16,
                                    color: (isDark ? AppTheme.textDark : AppTheme.textLight).withValues(alpha: 0.5)),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ws.name,
                                      style: TextStyle(fontSize: 14,
                                        fontWeight: ws.name == state.config?.currentWorkspace ? FontWeight.w700 : FontWeight.normal),
                                      overflow: TextOverflow.ellipsis),
                                    Text(ws.path,
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
                  // Add workspace
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 0.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _workspaceSwitcherOpen = false);
                        state.setScreen('setup');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text('+ Add workspace',
                          style: TextStyle(fontSize: 14, color: AppTheme.primary)),
                      ),
                    ),
                  ),
                ],
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
                Future.delayed(const Duration(milliseconds: 300), () {
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
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right, size: 16,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                ),
              ],
            ),
          ),
        ),
        if (_completedVisible)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _showCompleted ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
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

  const _ListTile({required this.list, required this.isActive, required this.onTap, required this.onDelete});

  @override
  State<_ListTile> createState() => _ListTileState();
}

class _ListTileState extends State<_ListTile> {
  bool _hovering = false;

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
