import 'dart:async';
import 'package:flutter/material.dart';
import '../rust/api.dart' as api;

class AppState extends ChangeNotifier {
  String screen = 'setup';
  api.AppConfigDto? config;
  List<api.TaskListDto> lists = [];
  String? activeListId;
  List<api.TaskDto> tasks = [];
  bool darkMode = true;
  StreamSubscription? _watcherSub;
  bool syncing = false;
  String? error;

  // Selected task for detail view
  String? selectedTaskId;

  api.TaskListDto? get activeList =>
      activeListId == null ? null : lists.cast<api.TaskListDto?>().firstWhere((l) => l?.id == activeListId, orElse: () => null);

  List<api.TaskDto> get pendingTasks => tasks.where((t) => t.status == 'backlog').toList();
  List<api.TaskDto> get completedTasks => tasks.where((t) => t.status == 'completed').toList();

  bool get hasWorkspace =>
      config != null && config!.currentWorkspace != null && config!.workspaces.isNotEmpty;

  api.TaskDto? get selectedTask =>
      selectedTaskId == null ? null : tasks.cast<api.TaskDto?>().firstWhere((t) => t?.id == selectedTaskId, orElse: () => null);

  Future<void> _startWatcher(String path) async {
    _watcherSub?.cancel();
    try {
      final stream = await api.watchWorkspaceChanges(path: path);
      _watcherSub = stream.listen((_) => loadLists());
    } catch (_) {}
  }

  Future<void> loadConfig() async {
    try {
      config = await api.getConfig();
      if (hasWorkspace) {
        screen = 'tasks';
        await loadLists();
        final ws = config!.workspaces.firstWhere((w) => w.name == config!.currentWorkspace);
        _startWatcher(ws.path);
      } else {
        screen = 'setup';
      }
    } catch (e) {
      config = const api.AppConfigDto(workspaces: [], currentWorkspace: null);
      screen = 'setup';
    }
    notifyListeners();
  }

  Future<void> addWorkspace(String name, String path) async {
    try {
      await api.initWorkspace(path: path);
      await api.addWorkspace(name: name, path: path);
      config = await api.getConfig();
      await loadLists();
      _startWatcher(path);
      screen = 'tasks';
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> switchWorkspace(String name) async {
    try {
      await api.setCurrentWorkspace(name: name);
      config = await api.getConfig();
      activeListId = null;
      await loadLists();
      final ws = config!.workspaces.firstWhere((w) => w.name == name);
      _startWatcher(ws.path);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeWorkspace(String name) async {
    try {
      await api.removeWorkspace(name: name);
      config = await api.getConfig();
      if (!hasWorkspace) {
        screen = 'setup';
        lists = [];
        tasks = [];
        activeListId = null;
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadLists() async {
    try {
      lists = await api.getLists();
      if (lists.isNotEmpty && activeListId == null) {
        activeListId = lists[0].id;
      }
      if (activeListId != null) await loadTasks();
    } catch (e) {
      error = e.toString();
    }
  }

  Future<void> loadTasks() async {
    if (activeListId == null) return;
    try {
      tasks = await api.listTasks(listId: activeListId!);
    } catch (e) {
      error = e.toString();
    }
  }

  Future<void> selectList(String id) async {
    activeListId = id;
    selectedTaskId = null;
    await loadTasks();
    notifyListeners();
  }

  Future<void> createList(String name) async {
    try {
      final list = await api.createList(name: name);
      lists = [...lists, list];
      activeListId = list.id;
      tasks = [];
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    try {
      await api.deleteList(listId: id);
      lists = lists.where((l) => l.id != id).toList();
      if (activeListId == id) {
        activeListId = lists.isNotEmpty ? lists[0].id : null;
        if (activeListId != null) {
          await loadTasks();
        } else {
          tasks = [];
        }
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<api.TaskDto?> createTask(String title, String description) async {
    if (activeListId == null) return null;
    try {
      final task = await api.createTask(listId: activeListId!, title: title, description: description);
      tasks = [...tasks, task];
      error = null;
      notifyListeners();
      return task;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleTask(String taskId) async {
    if (activeListId == null) return;
    try {
      final updated = await api.toggleTask(listId: activeListId!, taskId: taskId);
      if (updated.status == 'backlog') {
        tasks = [updated, ...tasks.where((t) => t.id != taskId)];
        try {
          await api.reorderTask(listId: activeListId!, taskId: taskId, newPosition: 0);
        } catch (_) {}
      } else {
        tasks = tasks.map((t) => t.id == taskId ? updated : t).toList();
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateTask(api.TaskDto task) async {
    if (activeListId == null) return;
    try {
      await api.updateTask(listId: activeListId!, task: task);
      tasks = tasks.map((t) => t.id == task.id ? task : t).toList();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> reorderTask(String taskId, int newPosition) async {
    if (activeListId == null) return;
    try {
      await api.reorderTask(listId: activeListId!, taskId: taskId, newPosition: newPosition);
      await loadTasks();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> moveTask(String taskId, String targetListId) async {
    if (activeListId == null) return;
    try {
      await api.moveTask(fromListId: activeListId!, toListId: targetListId, taskId: taskId);
      tasks = tasks.where((t) => t.id != taskId).toList();
      if (selectedTaskId == taskId) selectedTaskId = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> renameList(String listId, String newName) async {
    try {
      await api.renameList(listId: listId, newName: newName);
      await loadLists();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> setGroupByDueDate(String listId, bool enabled) async {
    try {
      await api.setGroupByDueDate(listId: listId, enabled: enabled);
      await loadLists();
      if (listId == activeListId) await loadTasks();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    if (activeListId == null) return;
    try {
      await api.deleteTask(listId: activeListId!, taskId: taskId);
      tasks = tasks.where((t) => t.id != taskId).toList();
      if (selectedTaskId == taskId) selectedTaskId = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void selectTask(String? taskId) {
    selectedTaskId = taskId;
    notifyListeners();
  }

  void toggleDarkMode() {
    darkMode = !darkMode;
    notifyListeners();
  }

  void setScreen(String s) {
    screen = s;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
