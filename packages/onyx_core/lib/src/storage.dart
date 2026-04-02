import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

import 'error.dart';
import 'models.dart';

/// Format a DateTime as ISO 8601 WITHOUT milliseconds (matching Rust's chrono output).
String _formatUtc(DateTime dt) {
  var u = dt.toUtc();
  var y = u.year.toString().padLeft(4, '0');
  var m = u.month.toString().padLeft(2, '0');
  var d = u.day.toString().padLeft(2, '0');
  var h = u.hour.toString().padLeft(2, '0');
  var mi = u.minute.toString().padLeft(2, '0');
  var s = u.second.toString().padLeft(2, '0');
  return '${y}-${m}-${d}T${h}:${mi}:${s}Z';
}

/// Parse a UTC ISO 8601 timestamp string into a DateTime.
DateTime _parseUtc(String s) => DateTime.parse(s).toUtc();

/// Metadata stored in root .metadata.json
class RootMetadata {
  int version;
  List<String> listOrder;
  String? lastOpenedList;

  RootMetadata({this.version = 1, List<String>? listOrder, this.lastOpenedList})
      : listOrder = listOrder ?? [];

  factory RootMetadata.fromJson(Map<String, dynamic> json) => RootMetadata(
        version: json['version'] as int? ?? 1,
        listOrder: (json['list_order'] as List<dynamic>?)?.cast<String>() ?? [],
        lastOpenedList: json['last_opened_list'] as String?,
      );

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{
      'version': version,
      'list_order': listOrder,
    };
    if (lastOpenedList != null) map['last_opened_list'] = lastOpenedList;
    return map;
  }
}

/// Metadata stored in each list's .listdata.json
class ListMetadata {
  String id;
  DateTime createdAt;
  DateTime updatedAt;
  bool groupByDueDate;
  List<String> taskOrder;

  ListMetadata({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.groupByDueDate = false,
    List<String>? taskOrder,
  }) : taskOrder = taskOrder ?? [];

  factory ListMetadata.create(String id) {
    var now = DateTime.now().toUtc();
    return ListMetadata(id: id, createdAt: now, updatedAt: now);
  }

  factory ListMetadata.fromJson(Map<String, dynamic> json) => ListMetadata(
        id: json['id'] as String,
        createdAt: _parseUtc(json['created_at'] as String),
        updatedAt: _parseUtc(json['updated_at'] as String),
        groupByDueDate: json['group_by_due_date'] as bool? ?? false,
        taskOrder: (json['task_order'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': _formatUtc(createdAt),
        'updated_at': _formatUtc(updatedAt),
        'group_by_due_date': groupByDueDate,
        'task_order': taskOrder,
      };
}

/// YAML frontmatter fields for a task markdown file.
class _TaskFrontmatter {
  String id;
  TaskStatus status;
  DateTime? due;
  bool hasTime;
  DateTime created;
  DateTime updated;
  String? parent;

  _TaskFrontmatter({
    required this.id,
    required this.status,
    this.due,
    this.hasTime = false,
    required this.created,
    required this.updated,
    this.parent,
  });

  factory _TaskFrontmatter.fromTask(Task task) => _TaskFrontmatter(
        id: task.id,
        status: task.status,
        due: task.dueDate,
        hasTime: task.hasTime,
        created: task.createdAt,
        updated: task.updatedAt,
        parent: task.parentId,
      );

  factory _TaskFrontmatter.fromYaml(YamlMap yaml) {
    var statusStr = yaml['status'] as String;
    var status = statusStr == 'completed' ? TaskStatus.completed : TaskStatus.backlog;
    return _TaskFrontmatter(
      id: yaml['id'] as String,
      status: status,
      due: yaml['due'] != null ? _parseUtc(yaml['due'] as String) : null,
      hasTime: yaml['has_time'] as bool? ?? false,
      created: _parseUtc(yaml['created'] as String),
      updated: _parseUtc(yaml['updated'] as String),
      parent: yaml['parent'] as String?,
    );
  }

  String toYamlString() {
    var buf = StringBuffer();
    buf.writeln('id: $id');
    buf.writeln('status: ${status == TaskStatus.completed ? 'completed' : 'backlog'}');
    if (due != null) buf.writeln('due: ${_formatUtc(due!)}');
    buf.writeln('has_time: $hasTime');
    buf.writeln('created: ${_formatUtc(created)}');
    buf.writeln('updated: ${_formatUtc(updated)}');
    if (parent != null) buf.writeln('parent: $parent');
    return buf.toString();
  }
}

/// Abstract storage interface matching the Rust Storage trait.
abstract class Storage {
  Task readTask(String listId, String taskId);
  void writeTask(String listId, Task task);
  void deleteTask(String listId, String taskId);
  List<Task> listTasks(String listId);

  TaskList createList(String name);
  List<TaskList> getLists();
  void deleteList(String listId);
  void renameList(String listId, String newName);

  RootMetadata readRootMetadata();
  void writeRootMetadata(RootMetadata metadata);
  ListMetadata readListMetadata(String listId);
  void writeListMetadata(ListMetadata metadata);
}

/// File-system-backed storage that reads/writes markdown+YAML tasks and JSON metadata.
class FileSystemStorage implements Storage {
  final String _rootPath;

  FileSystemStorage._(this._rootPath);

  /// Open an existing workspace. Throws if path does not exist.
  factory FileSystemStorage(String rootPath) {
    if (!Directory(rootPath).existsSync()) {
      throw NotFoundError('Path does not exist: $rootPath');
    }
    return FileSystemStorage._(rootPath);
  }

  /// Initialize a workspace, creating the directory and default metadata if needed.
  factory FileSystemStorage.init(String rootPath) {
    Directory(rootPath).createSync(recursive: true);
    var storage = FileSystemStorage._(rootPath);
    var metaFile = File(storage._metadataPath());
    if (!metaFile.existsSync()) {
      storage._writeRootMetadataInternal(RootMetadata());
    }
    return storage;
  }

  String _metadataPath() => p.join(_rootPath, '.metadata.json');

  /// Find the directory for a list by scanning for its .listdata.json with matching ID.
  String _listDirPath(String listId) {
    var rootDir = Directory(_rootPath);
    for (var entity in rootDir.listSync()) {
      if (entity is Directory) {
        var listdataFile = File(p.join(entity.path, '.listdata.json'));
        if (listdataFile.existsSync()) {
          var content = listdataFile.readAsStringSync();
          var json = jsonDecode(content) as Map<String, dynamic>;
          var meta = ListMetadata.fromJson(json);
          if (meta.id == listId) return entity.path;
        }
      }
    }
    throw ListNotFoundError(listId);
  }

  String _listDirPathByName(String name) => p.join(_rootPath, name);

  static String sanitizeFilename(String name) {
    var result = name.runes.map((r) {
      var c = String.fromCharCode(r);
      if (r <= 0x1f || '/\\:*?"<>|'.contains(c)) return '_';
      return c;
    }).join();
    // Trim leading/trailing dots and spaces
    result = result.replaceAll(RegExp(r'^[. ]+'), '');
    result = result.replaceAll(RegExp(r'[. ]+$'), '');
    return result;
  }

  String _taskFilePath(String listDir, Task task) {
    var safeTitle = sanitizeFilename(task.title);
    var filename = safeTitle.isEmpty ? task.id : safeTitle;
    return p.join(listDir, '$filename.md');
  }

  (_TaskFrontmatter, String) _parseMarkdownWithFrontmatter(String content) {
    var lines = content.split('\n');
    if (lines.isEmpty || lines[0] != '---') {
      throw InvalidDataError('Missing frontmatter delimiter');
    }
    var endIdx = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i] == '---') {
        endIdx = i;
        break;
      }
    }
    if (endIdx == -1) throw InvalidDataError('Missing closing frontmatter delimiter');

    var frontmatterStr = lines.sublist(1, endIdx).join('\n');
    YamlMap yamlMap;
    try {
      yamlMap = loadYaml(frontmatterStr) as YamlMap;
    } catch (e) {
      throw SerializationError('Failed to parse YAML frontmatter: $e');
    }
    var frontmatter = _TaskFrontmatter.fromYaml(yamlMap);

    var description = '';
    if (endIdx + 2 < lines.length) {
      description = lines.sublist(endIdx + 2).join('\n');
    }
    description = description.trim();

    return (frontmatter, description);
  }

  String _writeMarkdownWithFrontmatter(Task task) {
    var fm = _TaskFrontmatter.fromTask(task);
    var yaml = fm.toYamlString();
    var buf = StringBuffer();
    buf.write('---\n');
    buf.write(yaml);
    buf.write('---\n\n');
    buf.write(task.description);
    return buf.toString();
  }

  RootMetadata _readRootMetadataInternal() {
    var file = File(_metadataPath());
    if (!file.existsSync()) return RootMetadata();
    var content = file.readAsStringSync();
    return RootMetadata.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  void _writeRootMetadataInternal(RootMetadata metadata) {
    var file = File(_metadataPath());
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metadata.toJson()));
  }

  @override
  Task readTask(String listId, String taskId) {
    var listDir = _listDirPath(listId);
    var dir = Directory(listDir);
    for (var entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.md')) {
        var content = entity.readAsStringSync();
        var (fm, description) = _parseMarkdownWithFrontmatter(content);
        if (fm.id == taskId) {
          var title = p.basenameWithoutExtension(entity.path);
          return Task(
            id: fm.id,
            title: title,
            description: description,
            status: fm.status,
            dueDate: fm.due,
            hasTime: fm.hasTime,
            createdAt: fm.created,
            updatedAt: fm.updated,
            parentId: fm.parent,
          );
        }
      }
    }
    throw TaskNotFoundError(taskId);
  }

  @override
  void writeTask(String listId, Task task) {
    var listDir = _listDirPath(listId);
    var taskPath = _taskFilePath(listDir, task);

    // Remove old file if task was renamed (different filename, same ID)
    var dir = Directory(listDir);
    for (var entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.md') && entity.path != taskPath) {
        try {
          var content = entity.readAsStringSync();
          var (fm, _) = _parseMarkdownWithFrontmatter(content);
          if (fm.id == task.id) {
            entity.deleteSync();
            break;
          }
        } catch (_) {
          // Skip files that can't be parsed
        }
      }
    }

    var content = _writeMarkdownWithFrontmatter(task);
    File(taskPath).writeAsStringSync(content);

    // Update list metadata to include this task in task_order if not already present
    var listMeta = readListMetadata(listId);
    if (!listMeta.taskOrder.contains(task.id)) {
      listMeta.taskOrder.add(task.id);
      listMeta.updatedAt = DateTime.now().toUtc();
      writeListMetadata(listMeta);
    }
  }

  @override
  void deleteTask(String listId, String taskId) {
    var task = readTask(listId, taskId);
    var listDir = _listDirPath(listId);
    var taskPath = _taskFilePath(listDir, task);
    File(taskPath).deleteSync();

    // Remove from task_order
    var listMeta = readListMetadata(listId);
    listMeta.taskOrder.removeWhere((id) => id == taskId);
    listMeta.updatedAt = DateTime.now().toUtc();
    writeListMetadata(listMeta);
  }

  @override
  List<Task> listTasks(String listId) {
    var listDir = _listDirPath(listId);
    var listMeta = readListMetadata(listId);
    var tasks = <Task>[];
    var dir = Directory(listDir);

    for (var entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.md')) {
        var content = entity.readAsStringSync();
        var (fm, description) = _parseMarkdownWithFrontmatter(content);
        var title = p.basenameWithoutExtension(entity.path);
        tasks.add(Task(
          id: fm.id,
          title: title,
          description: description,
          status: fm.status,
          dueDate: fm.due,
          hasTime: fm.hasTime,
          createdAt: fm.created,
          updatedAt: fm.updated,
          parentId: fm.parent,
        ));
      }
    }

    // Sort by task_order
    var orderMap = <String, int>{};
    for (var i = 0; i < listMeta.taskOrder.length; i++) {
      orderMap[listMeta.taskOrder[i]] = i;
    }
    tasks.sort((a, b) {
      var ai = orderMap[a.id] ?? 0x7fffffff;
      var bi = orderMap[b.id] ?? 0x7fffffff;
      return ai.compareTo(bi);
    });

    return tasks;
  }

  @override
  TaskList createList(String name) {
    var listDir = _listDirPathByName(name);
    if (Directory(listDir).existsSync()) {
      throw InvalidDataError("List '$name' already exists");
    }

    Directory(listDir).createSync(recursive: true);

    var listId = const Uuid().v4();
    var listMeta = ListMetadata.create(listId);

    var metadataPath = p.join(listDir, '.listdata.json');
    File(metadataPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(listMeta.toJson()),
    );

    // Add to root metadata
    var rootMeta = _readRootMetadataInternal();
    rootMeta.listOrder.add(listId);
    rootMeta.lastOpenedList ??= listId;
    _writeRootMetadataInternal(rootMeta);

    return TaskList(
      id: listId,
      title: name,
      createdAt: listMeta.createdAt,
      updatedAt: listMeta.updatedAt,
      groupByDueDate: listMeta.groupByDueDate,
    );
  }

  @override
  List<TaskList> getLists() {
    var rootMeta = _readRootMetadataInternal();
    var lists = <TaskList>[];
    var rootDir = Directory(_rootPath);

    for (var entity in rootDir.listSync()) {
      if (entity is Directory) {
        var listdataFile = File(p.join(entity.path, '.listdata.json'));
        if (listdataFile.existsSync()) {
          var content = listdataFile.readAsStringSync();
          var listMeta = ListMetadata.fromJson(jsonDecode(content) as Map<String, dynamic>);
          var title = p.basename(entity.path);
          var tasks = listTasks(listMeta.id);

          lists.add(TaskList(
            id: listMeta.id,
            title: title,
            tasks: tasks,
            createdAt: listMeta.createdAt,
            updatedAt: listMeta.updatedAt,
            groupByDueDate: listMeta.groupByDueDate,
          ));
        }
      }
    }

    // Sort by list_order
    var orderMap = <String, int>{};
    for (var i = 0; i < rootMeta.listOrder.length; i++) {
      orderMap[rootMeta.listOrder[i]] = i;
    }
    lists.sort((a, b) {
      var ai = orderMap[a.id] ?? 0x7fffffff;
      var bi = orderMap[b.id] ?? 0x7fffffff;
      return ai.compareTo(bi);
    });

    return lists;
  }

  @override
  void deleteList(String listId) {
    var listDir = _listDirPath(listId);
    Directory(listDir).deleteSync(recursive: true);

    // Remove from root metadata
    var rootMeta = _readRootMetadataInternal();
    rootMeta.listOrder.removeWhere((id) => id == listId);
    if (rootMeta.lastOpenedList == listId) {
      rootMeta.lastOpenedList = rootMeta.listOrder.isNotEmpty ? rootMeta.listOrder.first : null;
    }
    _writeRootMetadataInternal(rootMeta);
  }

  @override
  void renameList(String listId, String newName) {
    var oldDir = _listDirPath(listId);
    var newDir = _listDirPathByName(newName);

    if (Directory(newDir).existsSync()) {
      throw InvalidDataError("A list named '$newName' already exists");
    }

    Directory(oldDir).renameSync(newDir);

    // Update metadata timestamp
    var metadataPath = p.join(newDir, '.listdata.json');
    var content = File(metadataPath).readAsStringSync();
    var metadata = ListMetadata.fromJson(jsonDecode(content) as Map<String, dynamic>);
    metadata.updatedAt = DateTime.now().toUtc();
    File(metadataPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
    );
  }

  @override
  RootMetadata readRootMetadata() => _readRootMetadataInternal();

  @override
  void writeRootMetadata(RootMetadata metadata) => _writeRootMetadataInternal(metadata);

  @override
  ListMetadata readListMetadata(String listId) {
    var listDir = _listDirPath(listId);
    var metadataPath = p.join(listDir, '.listdata.json');
    var file = File(metadataPath);
    if (!file.existsSync()) {
      throw NotFoundError('List metadata not found: $listId');
    }
    var content = file.readAsStringSync();
    return ListMetadata.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  @override
  void writeListMetadata(ListMetadata metadata) {
    var listDir = _listDirPath(metadata.id);
    var metadataPath = p.join(listDir, '.listdata.json');
    File(metadataPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
    );
  }
}
