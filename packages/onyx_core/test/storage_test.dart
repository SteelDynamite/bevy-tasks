import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:onyx_core/onyx_core.dart';
import 'package:onyx_core/src/storage.dart';

void main() {
  late Directory tempDir;
  late FileSystemStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('onyx_test_');
    storage = FileSystemStorage.init(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FileSystemStorage init/new', () {
    test('new on nonexistent path throws NotFoundError', () {
      expect(
        () => FileSystemStorage('/does/not/exist/ever'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('init creates metadata file', () {
      var metaFile = File('${tempDir.path}/.metadata.json');
      expect(metaFile.existsSync(), true);
    });

    test('init is idempotent', () {
      var list = storage.createList('Keep Me');
      var s2 = FileSystemStorage.init(tempDir.path);
      var lists = s2.getLists();
      expect(lists.length, 1);
      expect(lists[0].id, list.id);
    });
  });

  group('Root metadata', () {
    test('defaults when file is missing', () {
      File('${tempDir.path}/.metadata.json').deleteSync();
      var meta = storage.readRootMetadata();
      expect(meta.version, 1);
      expect(meta.listOrder, isEmpty);
    });
  });

  group('List operations', () {
    test('create list already exists throws', () {
      storage.createList('Dupes');
      expect(
        () => storage.createList('Dupes'),
        throwsA(isA<InvalidDataError>()),
      );
    });

    test('delete list cleans up root metadata', () {
      var list = storage.createList('To Delete');
      var metaBefore = storage.readRootMetadata();
      expect(metaBefore.listOrder.contains(list.id), true);

      storage.deleteList(list.id);
      var metaAfter = storage.readRootMetadata();
      expect(metaAfter.listOrder.contains(list.id), false);
    });

    test('list dir path for nonexistent list throws', () {
      expect(
        () => storage.readListMetadata('nonexistent-id'),
        throwsA(isA<ListNotFoundError>()),
      );
    });
  });

  group('Task file operations', () {
    test('write and read task roundtrip', () {
      var list = storage.createList('Tasks');
      var task = Task.create('Hello');
      storage.writeTask(list.id, task);
      var readBack = storage.readTask(list.id, task.id);
      expect(readBack.title, 'Hello');
      expect(readBack.id, task.id);
    });

    test('read nonexistent task throws', () {
      var list = storage.createList('Tasks');
      expect(
        () => storage.readTask(list.id, 'nonexistent-task-id'),
        throwsA(isA<TaskNotFoundError>()),
      );
    });

    test('write task adds to task order', () {
      var list = storage.createList('Tasks');
      var t1 = Task.create('First');
      var t2 = Task.create('Second');
      storage.writeTask(list.id, t1);
      storage.writeTask(list.id, t2);

      var meta = storage.readListMetadata(list.id);
      expect(meta.taskOrder.length, 2);
      expect(meta.taskOrder[0], t1.id);
      expect(meta.taskOrder[1], t2.id);
    });

    test('write task idempotent order', () {
      var list = storage.createList('Tasks');
      var task = Task.create('Once');
      storage.writeTask(list.id, task);
      storage.writeTask(list.id, task);

      var meta = storage.readListMetadata(list.id);
      expect(meta.taskOrder.length, 1);
    });

    test('delete task removes from order', () {
      var list = storage.createList('Tasks');
      var task = Task.create('Bye');
      storage.writeTask(list.id, task);
      storage.deleteTask(list.id, task.id);

      var meta = storage.readListMetadata(list.id);
      expect(meta.taskOrder.contains(task.id), false);
    });

    test('list tasks respects order', () {
      var list = storage.createList('Tasks');
      var t1 = Task.create('Alpha');
      var t2 = Task.create('Beta');
      var t3 = Task.create('Gamma');
      storage.writeTask(list.id, t1);
      storage.writeTask(list.id, t2);
      storage.writeTask(list.id, t3);

      // Rewrite metadata with custom order
      var meta = storage.readListMetadata(list.id);
      meta.taskOrder = [t3.id, t1.id, t2.id];
      storage.writeListMetadata(meta);

      var tasks = storage.listTasks(list.id);
      expect(tasks[0].id, t3.id);
      expect(tasks[1].id, t1.id);
      expect(tasks[2].id, t2.id);
    });

    test('list tasks empty list', () {
      var list = storage.createList('Empty');
      var tasks = storage.listTasks(list.id);
      expect(tasks, isEmpty);
    });
  });

  group('Frontmatter parsing', () {
    test('markdown roundtrip preserves description', () {
      var list = storage.createList('Test');
      var task = Task.create('Test').withDescription('Line 1\n\nLine 3');
      storage.writeTask(list.id, task);
      var readBack = storage.readTask(list.id, task.id);
      expect(readBack.description, 'Line 1\n\nLine 3');
    });

    test('frontmatter date format has no milliseconds', () {
      var list = storage.createList('Test');
      var task = Task.create('Check Format');
      storage.writeTask(list.id, task);

      // Read raw file content
      var taskFile = File('${tempDir.path}/Test/Check Format.md');
      var content = taskFile.readAsStringSync();
      // Should not contain fractional seconds like .000
      expect(content.contains('.000'), false);
      // Should contain Z suffix
      expect(content.contains('Z'), true);
    });
  });

  group('Filename sanitization', () {
    test('replaces invalid characters', () {
      expect(FileSystemStorage.sanitizeFilename('a/b\\c:d'), 'a_b_c_d');
      expect(FileSystemStorage.sanitizeFilename('test*file?"yes"'), 'test_file__yes_');
    });

    test('trims dots and spaces', () {
      expect(FileSystemStorage.sanitizeFilename('..name..'), 'name');
      expect(FileSystemStorage.sanitizeFilename('  name  '), 'name');
    });
  });
}
