import 'package:flutter/material.dart';
import '../src/rust/api.dart' as api;

enum AppScreen { setup, tasks, settings }

class AppProvider extends ChangeNotifier {
  AppScreen _screen = AppScreen.setup;
  bool _darkMode = false;
  bool _syncing = false;
  String? _error;

  List<api.BridgeWorkspace> _workspaces = [];
  String? _currentWorkspace;

  List<api.BridgeTaskList> _lists = [];
  String? _activeListId;
  List<api.BridgeTask> _tasks = [];

  // ── Getters ──────────────────────────────────────────────────────

  AppScreen get screen => _screen;
  bool get darkMode => _darkMode;
  bool get syncing => _syncing;
  String? get error => _error;
  List<api.BridgeWorkspace> get workspaces => _workspaces;
  String? get currentWorkspace => _currentWorkspace;
  List<api.BridgeTaskList> get lists => _lists;
  String? get activeListId => _activeListId;
  api.BridgeTaskList? get activeList =>
      _activeListId == null ? null : _lists.where((l) => l.id == _activeListId).firstOrNull;
  List<api.BridgeTask> get tasks => _tasks;
  List<api.BridgeTask> get pendingTasks => _tasks.where((t) => t.status != 'completed').toList();
  List<api.BridgeTask> get completedTasks => _tasks.where((t) => t.status == 'completed').toList();
  bool get hasWorkspace => _currentWorkspace != null && _workspaces.isNotEmpty;

  // ── Init ─────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final config = await api.initApp();
      _workspaces = config.workspaces;
      _currentWorkspace = config.currentWorkspace;
      if (hasWorkspace) {
        _screen = AppScreen.tasks;
        await loadLists();
      }
    } catch (e) {
      _screen = AppScreen.setup;
    }
    notifyListeners();
  }

  // ── Navigation ───────────────────────────────────────────────────

  void setScreen(AppScreen s) {
    _screen = s;
    notifyListeners();
  }

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Workspace operations ─────────────────────────────────────────

  Future<void> addWorkspace(String name, String path) async {
    try {
      await api.addWorkspace(name: name, path: path);
      final config = await api.getConfig();
      _workspaces = config.workspaces;
      _currentWorkspace = config.currentWorkspace;
      _screen = AppScreen.tasks;
      _error = null;
      await loadLists();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> switchWorkspace(String name) async {
    try {
      await api.setCurrentWorkspace(name: name);
      final config = await api.getConfig();
      _workspaces = config.workspaces;
      _currentWorkspace = config.currentWorkspace;
      _activeListId = null;
      await loadLists();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeWorkspace(String name) async {
    try {
      await api.removeWorkspace(name: name);
      final config = await api.getConfig();
      _workspaces = config.workspaces;
      _currentWorkspace = config.currentWorkspace;
      if (!hasWorkspace) {
        _screen = AppScreen.setup;
        _lists = [];
        _tasks = [];
        _activeListId = null;
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // ── List operations ──────────────────────────────────────────────

  Future<void> loadLists() async {
    try {
      _lists = await api.getLists();
      if (_lists.isNotEmpty && _activeListId == null) {
        _activeListId = _lists.first.id;
      }
      if (_activeListId != null) await loadTasks();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> selectList(String id) async {
    _activeListId = id;
    await loadTasks();
    notifyListeners();
  }

  Future<void> createList(String name) async {
    try {
      final list = await api.createList(name: name);
      _lists.add(list);
      _activeListId = list.id;
      _tasks = [];
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    try {
      await api.deleteList(listId: id);
      _lists.removeWhere((l) => l.id == id);
      if (_activeListId == id) {
        _activeListId = _lists.isNotEmpty ? _lists.first.id : null;
        if (_activeListId != null) await loadTasks();
        else _tasks = [];
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // ── Task operations ──────────────────────────────────────────────

  Future<void> loadTasks() async {
    if (_activeListId == null) return;
    try {
      _tasks = await api.listTasks(listId: _activeListId!);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> createTask(String title) async {
    if (_activeListId == null) return;
    try {
      final task = await api.createTask(listId: _activeListId!, title: title);
      _tasks.add(task);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> toggleTask(String taskId) async {
    if (_activeListId == null) return;
    try {
      await api.toggleTask(listId: _activeListId!, taskId: taskId);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTask(String taskId, String title, String description) async {
    if (_activeListId == null) return;
    try {
      await api.updateTask(listId: _activeListId!, taskId: taskId, title: title, description: description);
      await loadTasks();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    if (_activeListId == null) return;
    try {
      await api.deleteTask(listId: _activeListId!, taskId: taskId);
      _tasks.removeWhere((t) => t.id == taskId);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // ── Sync ─────────────────────────────────────────────────────────

  Future<void> triggerSync() async {
    if (_currentWorkspace == null) return;
    final ws = _workspaces.where((w) => w.name == _currentWorkspace).firstOrNull;
    if (ws == null || ws.webdavUrl == null) {
      _error = 'No WebDAV URL configured';
      notifyListeners();
      return;
    }
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      final result = await api.syncWorkspaceBridge(
        workspacePath: ws.path,
        webdavUrl: ws.webdavUrl!,
        username: '',
        password: '',
      );
      if (result.errors.isNotEmpty) {
        _error = result.errors.join('; ');
      }
      await loadLists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
