import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onyx_core/onyx_core.dart';

class AppState extends ChangeNotifier {
  String screen = 'setup';
  AppConfig? config;
  String? _configPath;
  TaskRepository? _repo;
  List<TaskList> lists = [];
  String? activeListId;
  List<Task> tasks = [];
  bool darkMode = true;
  StreamSubscription? _watcherSub;
  DateTime? _lastWrite;
  bool syncing = false;
  String syncMode = 'full';
  SyncResult? lastSyncResult;
  String? error;
  String? selectedTaskId;

  /// Credential store for WebDAV (injected by caller for platform flexibility).
  CredentialStore credentialStore = EnvVarCredentialStore();

  TaskList? get activeList =>
      activeListId == null ? null : lists.cast<TaskList?>().firstWhere((l) => l?.id == activeListId, orElse: () => null);

  List<Task> get pendingTasks => tasks.where((t) => t.status == TaskStatus.backlog).toList();
  List<Task> get completedTasks => tasks.where((t) => t.status == TaskStatus.completed).toList();

  bool get hasWorkspace =>
      config != null && config!.currentWorkspace != null && config!.workspaces.isNotEmpty;

  Task? get selectedTask =>
      selectedTaskId == null ? null : tasks.cast<Task?>().firstWhere((t) => t?.id == selectedTaskId, orElse: () => null);

  String _getConfigPath() {
    _configPath ??= AppConfig.getConfigPath();
    return _configPath!;
  }

  void setConfigPath(String path) => _configPath = path;

  void _muteWatcher() {
    _lastWrite = DateTime.now();
  }

  Future<void> _startWatcher(String path) async {
    _watcherSub?.cancel();
    try {
      var dir = Directory(path);
      if (!dir.existsSync()) return;
      Timer? debounce;
      _watcherSub = dir.watch(recursive: true).listen((event) {
        // Only care about .md and .json files
        if (!event.path.endsWith('.md') && !event.path.endsWith('.json')) return;
        // Self-change suppression
        if (_lastWrite != null && DateTime.now().difference(_lastWrite!).inMilliseconds < 1000) return;
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 500), () => loadLists());
      });
    } catch (_) {}
  }

  Future<void> loadConfig() async {
    try {
      config = AppConfig.loadFromFile(_getConfigPath());
      if (hasWorkspace) {
        screen = 'tasks';
        var (_, ws) = config!.getCurrentWorkspace();
        _repo = TaskRepository(ws.path);
        await loadLists();
        _startWatcher(ws.path);
      } else {
        screen = 'setup';
      }
    } catch (e) {
      config = AppConfig();
      screen = 'setup';
    }
    notifyListeners();
  }

  Future<void> addWorkspace(String name, String path) async {
    try {
      _repo = TaskRepository.init(path);
      config ??= AppConfig();
      config!.addWorkspace(name, WorkspaceConfig(path: path));
      config!.currentWorkspace = name;
      config!.saveToFile(_getConfigPath());
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
      config!.setCurrentWorkspace(name);
      config!.saveToFile(_getConfigPath());
      var ws = config!.getWorkspace(name)!;
      _repo = TaskRepository(ws.path);
      activeListId = null;
      await loadLists();
      _startWatcher(ws.path);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeWorkspace(String name) async {
    try {
      config!.removeWorkspace(name);
      config!.saveToFile(_getConfigPath());
      if (!hasWorkspace) {
        screen = 'setup';
        lists = [];
        tasks = [];
        activeListId = null;
        _repo = null;
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadLists() async {
    if (_repo == null) return;
    try {
      _muteWatcher();
      lists = _repo!.getLists();
      if (lists.isNotEmpty && activeListId == null)
        activeListId = lists[0].id;
      if (activeListId != null) await loadTasks();
    } catch (e) {
      error = e.toString();
    }
  }

  Future<void> loadTasks() async {
    if (activeListId == null || _repo == null) return;
    try {
      tasks = _repo!.listTasks(activeListId!);
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
    if (_repo == null) return;
    try {
      _muteWatcher();
      var list = _repo!.createList(name);
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
    if (_repo == null) return;
    try {
      _muteWatcher();
      _repo!.deleteList(id);
      lists = lists.where((l) => l.id != id).toList();
      if (activeListId == id) {
        activeListId = lists.isNotEmpty ? lists[0].id : null;
        if (activeListId != null)
          await loadTasks();
        else
          tasks = [];
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<Task?> createTask(String title, String description) async {
    if (activeListId == null || _repo == null) return null;
    try {
      _muteWatcher();
      var task = Task.create(title).withDescription(description);
      _repo!.createTask(activeListId!, task);
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
    if (activeListId == null || _repo == null) return;
    try {
      _muteWatcher();
      var task = _repo!.getTask(activeListId!, taskId);
      if (task.status == TaskStatus.completed)
        task.uncomplete();
      else
        task.complete();
      _repo!.updateTask(activeListId!, task);
      if (task.status == TaskStatus.backlog) {
        tasks = [task, ...tasks.where((t) => t.id != taskId)];
        try {
          _repo!.reorderTask(activeListId!, taskId, 0);
        } catch (_) {}
      } else {
        tasks = tasks.map((t) => t.id == taskId ? task : t).toList();
      }
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    if (activeListId == null || _repo == null) return;
    try {
      _muteWatcher();
      _repo!.updateTask(activeListId!, task);
      tasks = tasks.map((t) => t.id == task.id ? task : t).toList();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> reorderTask(String taskId, int newPosition) async {
    if (activeListId == null || _repo == null) return;
    try {
      _muteWatcher();
      _repo!.reorderTask(activeListId!, taskId, newPosition);
      await loadTasks();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> moveTask(String taskId, String targetListId) async {
    if (activeListId == null || _repo == null) return;
    try {
      _muteWatcher();
      _repo!.moveTask(activeListId!, targetListId, taskId);
      tasks = tasks.where((t) => t.id != taskId).toList();
      if (selectedTaskId == taskId) selectedTaskId = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> renameList(String listId, String newName) async {
    if (_repo == null) return;
    try {
      _muteWatcher();
      _repo!.renameList(listId, newName);
      lists = _repo!.getLists();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> setGroupByDueDate(String listId, bool enabled) async {
    if (_repo == null) return;
    try {
      _muteWatcher();
      _repo!.setGroupByDueDate(listId, enabled);
      lists = _repo!.getLists();
      if (listId == activeListId) await loadTasks();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    if (activeListId == null || _repo == null) return;
    try {
      _muteWatcher();
      _repo!.deleteTask(activeListId!, taskId);
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

  void setSyncMode(String mode) {
    syncMode = mode;
    notifyListeners();
  }

  Future<void> triggerSync() async {
    if (config?.currentWorkspace == null) return;
    var (wsName, ws) = config!.getCurrentWorkspace();
    if (ws.webdavUrl == null) {
      error = 'No WebDAV URL configured';
      notifyListeners();
      return;
    }
    syncing = true;
    error = null;
    notifyListeners();
    try {
      var domain = Uri.parse(ws.webdavUrl!).host;
      var creds = credentialStore.loadCredentials(domain);
      if (creds == null) throw CredentialError('No credentials found for $domain');
      var mode = switch (syncMode) {
        'push' => SyncMode.push,
        'pull' => SyncMode.pull,
        _ => SyncMode.full,
      };
      var result = await syncWorkspace(
        workspacePath: ws.path,
        webdavUrl: ws.webdavUrl!,
        username: creds.$1,
        password: creds.$2,
        mode: mode,
      );
      lastSyncResult = result;
      if (result.errors.isNotEmpty) error = result.errors.join('; ');
      ws.lastSync = DateTime.now().toUtc();
      config!.saveToFile(_getConfigPath());
      _repo = TaskRepository(ws.path);
      lists = _repo!.getLists();
    } catch (e) {
      error = e.toString();
    }
    syncing = false;
    notifyListeners();
  }

  /// Save WebDAV config for the current workspace.
  void setWebdavConfig(String webdavUrl) {
    if (config?.currentWorkspace == null) return;
    var (_, ws) = config!.getCurrentWorkspace();
    ws.webdavUrl = webdavUrl;
    config!.saveToFile(_getConfigPath());
  }

  /// Test WebDAV connection.
  Future<void> testWebdavConnection(String url, String username, String password) async {
    var client = WebDavClient(url, username, password);
    await client.testConnection();
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
