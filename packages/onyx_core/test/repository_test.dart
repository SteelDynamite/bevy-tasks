import 'dart:io';

import 'package:test/test.dart';
import 'package:onyx_core/onyx_core.dart';

void main() {
  late Directory tempDir;
  late TaskRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('onyx_repo_test_');
    repo = TaskRepository.init(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('init repository succeeds', () {
    expect(repo, isNotNull);
  });

  test('create and list tasks', () {
    var list = repo.createList('Test List');
    var task = Task.create('Test Task');
    repo.createTask(list.id, task);
    var tasks = repo.listTasks(list.id);
    expect(tasks.length, 1);
    expect(tasks[0].title, 'Test Task');
  });

  test('update task', () {
    var list = repo.createList('Test List');
    var task = Task.create('Original');
    task = repo.createTask(list.id, task);
    task.title = 'Updated';
    repo.updateTask(list.id, task);
    var retrieved = repo.getTask(list.id, task.id);
    expect(retrieved.title, 'Updated');
  });

  test('delete task', () {
    var list = repo.createList('Test List');
    var task = Task.create('To Delete');
    task = repo.createTask(list.id, task);
    repo.deleteTask(list.id, task.id);
    var tasks = repo.listTasks(list.id);
    expect(tasks.length, 0);
  });

  test('reorder tasks', () {
    var list = repo.createList('Test List');
    var t1 = repo.createTask(list.id, Task.create('Task 1'));
    var t2 = repo.createTask(list.id, Task.create('Task 2'));
    var t3 = repo.createTask(list.id, Task.create('Task 3'));

    repo.reorderTask(list.id, t3.id, 0);
    var order = repo.getTaskOrder(list.id);
    expect(order[0], t3.id);
    expect(order[1], t1.id);
    expect(order[2], t2.id);
  });

  test('group by due date', () {
    var list = repo.createList('Test List');
    expect(repo.getGroupByDueDate(list.id), false);
    repo.setGroupByDueDate(list.id, true);
    expect(repo.getGroupByDueDate(list.id), true);
    repo.setGroupByDueDate(list.id, false);
    expect(repo.getGroupByDueDate(list.id), false);
  });

  group('Error paths', () {
    test('get task not found', () {
      var list = repo.createList('Test');
      expect(() => repo.getTask(list.id, 'nonexistent'), throwsA(isA<TaskNotFoundError>()));
    });

    test('update nonexistent task', () {
      var list = repo.createList('Test');
      var task = Task.create('Ghost');
      expect(() => repo.updateTask(list.id, task), throwsA(isA<TaskNotFoundError>()));
    });

    test('delete nonexistent task', () {
      var list = repo.createList('Test');
      expect(() => repo.deleteTask(list.id, 'nonexistent'), throwsA(isA<TaskNotFoundError>()));
    });

    test('get list not found', () {
      expect(() => repo.getList('nonexistent'), throwsA(isA<ListNotFoundError>()));
    });

    test('delete nonexistent list', () {
      expect(() => repo.deleteList('nonexistent'), throwsA(isA<ListNotFoundError>()));
    });

    test('list tasks nonexistent list', () {
      expect(() => repo.listTasks('nonexistent'), throwsA(isA<ListNotFoundError>()));
    });

    test('reorder task not in list', () {
      var list = repo.createList('Test');
      repo.createTask(list.id, Task.create('A'));
      expect(() => repo.reorderTask(list.id, 'nonexistent', 0), throwsA(isA<TaskNotFoundError>()));
    });

    test('reorder task position clamped', () {
      var list = repo.createList('Test');
      var t1 = repo.createTask(list.id, Task.create('A'));
      var t2 = repo.createTask(list.id, Task.create('B'));
      repo.reorderTask(list.id, t1.id, 999);
      var order = repo.getTaskOrder(list.id);
      expect(order[0], t2.id);
      expect(order[1], t1.id);
    });

    test('create duplicate list', () {
      repo.createList('Dupes');
      expect(() => repo.createList('Dupes'), throwsA(isA<InvalidDataError>()));
    });
  });

  test('get lists empty', () {
    var lists = repo.getLists();
    expect(lists, isEmpty);
  });

  test('move task between lists', () {
    var listA = repo.createList('List A');
    var listB = repo.createList('List B');
    var task = repo.createTask(listA.id, Task.create('Movable'));

    repo.moveTask(listA.id, listB.id, task.id);

    expect(repo.listTasks(listA.id).length, 0);
    var tasksB = repo.listTasks(listB.id);
    expect(tasksB.length, 1);
    expect(tasksB[0].title, 'Movable');
  });

  test('rename list', () {
    var list = repo.createList('Old Name');
    repo.renameList(list.id, 'New Name');
    var renamed = repo.getList(list.id);
    expect(renamed.title, 'New Name');
    expect(Directory('${tempDir.path}/Old Name').existsSync(), false);
    expect(Directory('${tempDir.path}/New Name').existsSync(), true);
  });

  test('rename list duplicate name throws', () {
    repo.createList('A');
    var listB = repo.createList('B');
    expect(() => repo.renameList(listB.id, 'A'), throwsA(isA<InvalidDataError>()));
  });

  test('delete list removes from root metadata', () {
    var list1 = repo.createList('A');
    var list2 = repo.createList('B');
    repo.deleteList(list1.id);
    var lists = repo.getLists();
    expect(lists.length, 1);
    expect(lists[0].id, list2.id);
  });

  test('new on nonexistent path throws', () {
    expect(() => TaskRepository('/nonexistent/path/that/does/not/exist'), throwsA(isA<NotFoundError>()));
  });

  test('task with description roundtrip', () {
    var list = repo.createList('Test');
    var task = Task.create('Has Description').withDescription('Some **markdown** notes');
    var created = repo.createTask(list.id, task);
    var retrieved = repo.getTask(list.id, created.id);
    expect(retrieved.description, 'Some **markdown** notes');
  });

  test('task rename removes old file', () {
    var list = repo.createList('Test');
    var task = repo.createTask(list.id, Task.create('Old Name'));
    task.title = 'New Name';
    repo.updateTask(list.id, task);

    var tasks = repo.listTasks(list.id);
    expect(tasks.length, 1);
    expect(tasks[0].title, 'New Name');

    var oldFile = File('${tempDir.path}/Test/Old Name.md');
    expect(oldFile.existsSync(), false);
  });

  test('task order after delete', () {
    var list = repo.createList('Test');
    var t1 = repo.createTask(list.id, Task.create('A'));
    var t2 = repo.createTask(list.id, Task.create('B'));
    var t3 = repo.createTask(list.id, Task.create('C'));

    repo.deleteTask(list.id, t2.id);
    var order = repo.getTaskOrder(list.id);
    expect(order.length, 2);
    expect(order[0], t1.id);
    expect(order[1], t3.id);
  });
}
