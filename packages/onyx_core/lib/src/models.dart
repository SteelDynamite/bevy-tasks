import 'package:uuid/uuid.dart';

enum TaskStatus { backlog, completed }

/// A single task with metadata, stored as a markdown file with YAML frontmatter.
class Task {
  String id;
  String title;
  String description;
  TaskStatus status;
  DateTime? dueDate;
  bool hasTime;
  DateTime createdAt;
  DateTime updatedAt;
  String? parentId;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.backlog,
    this.dueDate,
    this.hasTime = false,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  /// Create a new task with generated UUID and current UTC timestamps.
  factory Task.create(String title) {
    var now = DateTime.now().toUtc();
    return Task(
      id: const Uuid().v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Mark task as completed, updating the timestamp.
  void complete() {
    status = TaskStatus.completed;
    updatedAt = DateTime.now().toUtc();
  }

  /// Restore task to backlog, updating the timestamp.
  void uncomplete() {
    status = TaskStatus.backlog;
    updatedAt = DateTime.now().toUtc();
  }

  /// Return a copy with the given description set.
  Task withDescription(String desc) {
    description = desc;
    return this;
  }

  /// Return a copy with the given due date set.
  Task withDueDate(DateTime due) {
    dueDate = due;
    return this;
  }

  /// Return a copy with the given parent ID set.
  Task withParent(String pid) {
    parentId = pid;
    return this;
  }
}

/// A named list of tasks, corresponding to a directory on disk.
class TaskList {
  String id;
  String title;
  List<Task> tasks;
  DateTime createdAt;
  DateTime updatedAt;
  bool groupByDueDate;

  TaskList({
    required this.id,
    required this.title,
    List<Task>? tasks,
    required this.createdAt,
    required this.updatedAt,
    this.groupByDueDate = false,
  }) : tasks = tasks ?? [];

  /// Create a new task list with generated UUID and current UTC timestamps.
  factory TaskList.create(String title) {
    var now = DateTime.now().toUtc();
    return TaskList(
      id: const Uuid().v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  void addTask(Task task) {
    tasks.add(task);
    updatedAt = DateTime.now().toUtc();
  }

  Task? removeTask(String taskId) {
    var idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return null;
    updatedAt = DateTime.now().toUtc();
    return tasks.removeAt(idx);
  }

  Task? getTask(String taskId) {
    for (var t in tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  bool updateTask(Task task) {
    var idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return false;
    tasks[idx] = task;
    updatedAt = DateTime.now().toUtc();
    return true;
  }
}
