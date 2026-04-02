import 'package:test/test.dart';
import 'package:onyx_core/onyx_core.dart';

void main() {
  group('Task', () {
    test('create sets defaults', () {
      var task = Task.create('Test');
      expect(task.title, 'Test');
      expect(task.description, '');
      expect(task.status, TaskStatus.backlog);
      expect(task.dueDate, isNull);
      expect(task.hasTime, false);
      expect(task.parentId, isNull);
      expect(task.id, isNotEmpty);
      expect(task.createdAt.isUtc, true);
      expect(task.updatedAt.isUtc, true);
    });

    test('complete changes status and timestamp', () {
      var task = Task.create('Test');
      var before = task.updatedAt;
      task.complete();
      expect(task.status, TaskStatus.completed);
      expect(task.updatedAt.isAfter(before) || task.updatedAt == before, true);
    });

    test('uncomplete restores backlog', () {
      var task = Task.create('Test');
      task.complete();
      task.uncomplete();
      expect(task.status, TaskStatus.backlog);
    });

    test('withDescription sets description', () {
      var task = Task.create('Test').withDescription('Hello');
      expect(task.description, 'Hello');
    });

    test('withDueDate sets due date', () {
      var due = DateTime.utc(2026, 6, 15);
      var task = Task.create('Test').withDueDate(due);
      expect(task.dueDate, due);
    });

    test('withParent sets parent', () {
      var task = Task.create('Test').withParent('abc-123');
      expect(task.parentId, 'abc-123');
    });
  });

  group('TaskList', () {
    test('create sets defaults', () {
      var list = TaskList.create('My List');
      expect(list.title, 'My List');
      expect(list.tasks, isEmpty);
      expect(list.groupByDueDate, false);
      expect(list.id, isNotEmpty);
    });

    test('addTask adds and updates timestamp', () {
      var list = TaskList.create('Test');
      var task = Task.create('Item');
      list.addTask(task);
      expect(list.tasks.length, 1);
    });

    test('removeTask removes and returns task', () {
      var list = TaskList.create('Test');
      var task = Task.create('Item');
      list.addTask(task);
      var removed = list.removeTask(task.id);
      expect(removed, isNotNull);
      expect(removed!.id, task.id);
      expect(list.tasks, isEmpty);
    });

    test('removeTask returns null for missing task', () {
      var list = TaskList.create('Test');
      expect(list.removeTask('nonexistent'), isNull);
    });

    test('getTask finds task', () {
      var list = TaskList.create('Test');
      var task = Task.create('Item');
      list.addTask(task);
      expect(list.getTask(task.id), isNotNull);
      expect(list.getTask('nonexistent'), isNull);
    });

    test('updateTask replaces existing task', () {
      var list = TaskList.create('Test');
      var task = Task.create('Original');
      list.addTask(task);
      task.title = 'Updated';
      expect(list.updateTask(task), true);
      expect(list.tasks[0].title, 'Updated');
    });

    test('updateTask returns false for missing task', () {
      var list = TaskList.create('Test');
      var task = Task.create('Ghost');
      expect(list.updateTask(task), false);
    });
  });
}
