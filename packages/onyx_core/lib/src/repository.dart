import 'error.dart';
import 'models.dart';
import 'storage.dart';

/// High-level API wrapping Storage for task/list CRUD, ordering, and grouping.
class TaskRepository {
  final Storage _storage;

  TaskRepository._(this._storage);

  /// Open an existing workspace at the given path.
  factory TaskRepository(String tasksFolder) {
    var storage = FileSystemStorage(tasksFolder);
    return TaskRepository._(storage);
  }

  /// Initialize a workspace (creates directory + default metadata if needed).
  factory TaskRepository.init(String tasksFolder) {
    var storage = FileSystemStorage.init(tasksFolder);
    return TaskRepository._(storage);
  }

  // --- Task operations ---

  Task createTask(String listId, Task task) {
    _storage.writeTask(listId, task);
    return task;
  }

  Task getTask(String listId, String taskId) => _storage.readTask(listId, taskId);

  void updateTask(String listId, Task task) {
    // Verify task exists first
    _storage.readTask(listId, task.id);
    _storage.writeTask(listId, task);
  }

  void deleteTask(String listId, String taskId) => _storage.deleteTask(listId, taskId);

  List<Task> listTasks(String listId) => _storage.listTasks(listId);

  // --- List operations ---

  TaskList createList(String name) => _storage.createList(name);

  List<TaskList> getLists() => _storage.getLists();

  TaskList getList(String listId) {
    var lists = getLists();
    for (var list in lists) {
      if (list.id == listId) return list;
    }
    throw ListNotFoundError(listId);
  }

  void deleteList(String listId) => _storage.deleteList(listId);

  void renameList(String listId, String newName) => _storage.renameList(listId, newName);

  void moveTask(String fromListId, String toListId, String taskId) {
    var task = _storage.readTask(fromListId, taskId);
    _storage.writeTask(toListId, task);
    _storage.deleteTask(fromListId, taskId);
  }

  // --- Task ordering ---

  void reorderTask(String listId, String taskId, int newPosition) {
    var metadata = _storage.readListMetadata(listId);
    var currentPos = metadata.taskOrder.indexOf(taskId);
    if (currentPos == -1) throw TaskNotFoundError(taskId);

    metadata.taskOrder.removeAt(currentPos);
    var newPos = newPosition.clamp(0, metadata.taskOrder.length);
    metadata.taskOrder.insert(newPos, taskId);

    metadata.updatedAt = DateTime.now().toUtc();
    _storage.writeListMetadata(metadata);
  }

  List<String> getTaskOrder(String listId) {
    var metadata = _storage.readListMetadata(listId);
    return metadata.taskOrder;
  }

  // --- Grouping preference ---

  void setGroupByDueDate(String listId, bool enabled) {
    var metadata = _storage.readListMetadata(listId);
    metadata.groupByDueDate = enabled;
    metadata.updatedAt = DateTime.now().toUtc();
    _storage.writeListMetadata(metadata);
  }

  bool getGroupByDueDate(String listId) {
    var metadata = _storage.readListMetadata(listId);
    return metadata.groupByDueDate;
  }
}
