import 'dart:io';

import 'package:test/test.dart';
import 'package:onyx_core/onyx_core.dart';

LocalFileInfo _makeLocal(String path, String checksum) => LocalFileInfo(
      path: path,
      checksum: checksum,
      modifiedAt: '2026-01-15T12:00:00+00:00',
      size: 100,
    );

RemoteFileSnapshot _makeRemote(String path) => RemoteFileSnapshot(
      path: path,
      lastModified: 'Mon, 01 Jan 2026 00:00:00 GMT',
      size: 100,
    );

SyncFileEntry _makeBase(String checksum) => SyncFileEntry(
      checksum: checksum,
      modifiedAt: 'Mon, 01 Jan 2026 00:00:00 GMT',
      size: 100,
    );

void main() {
  group('computeSyncActions', () {
    test('unchanged both sides', () {
      var local = [_makeLocal('file.md', 'abc123')];
      var remote = [_makeRemote('file.md')];
      var state = SyncState();
      state.files['file.md'] = _makeBase('abc123');

      var actions = computeSyncActions(local, remote, state);
      expect(actions, isEmpty);
    });

    test('local added remote absent', () {
      var local = [_makeLocal('new.md', 'abc123')];
      var actions = computeSyncActions(local, [], SyncState());
      expect(actions.length, 1);
      expect(actions[0], isA<UploadAction>());
      expect(actions[0].path, 'new.md');
    });

    test('remote added local absent', () {
      var remote = [_makeRemote('new.md')];
      var actions = computeSyncActions([], remote, SyncState());
      expect(actions.length, 1);
      expect(actions[0], isA<DownloadAction>());
      expect(actions[0].path, 'new.md');
    });

    test('local modified remote unchanged', () {
      var local = [_makeLocal('file.md', 'new_checksum')];
      var remote = [_makeRemote('file.md')];
      var state = SyncState();
      state.files['file.md'] = _makeBase('old_checksum');

      var actions = computeSyncActions(local, remote, state);
      expect(actions.length, 1);
      expect(actions[0], isA<UploadAction>());
    });

    test('remote modified local unchanged', () {
      var local = [_makeLocal('file.md', 'same_checksum')];
      var remote = [RemoteFileSnapshot(path: 'file.md', lastModified: 'Mon, 01 Jan 2026 00:00:00 GMT', size: 200)];
      var state = SyncState();
      state.files['file.md'] = _makeBase('same_checksum');

      var actions = computeSyncActions(local, remote, state);
      expect(actions.length, 1);
      expect(actions[0], isA<DownloadAction>());
    });

    test('local deleted remote unchanged', () {
      var remote = [_makeRemote('file.md')];
      var state = SyncState();
      state.files['file.md'] = _makeBase('abc123');

      var actions = computeSyncActions([], remote, state);
      expect(actions.length, 1);
      expect(actions[0], isA<DeleteRemoteAction>());
    });

    test('remote deleted local unchanged', () {
      var local = [_makeLocal('file.md', 'abc123')];
      var state = SyncState();
      state.files['file.md'] = _makeBase('abc123');

      var actions = computeSyncActions(local, [], state);
      expect(actions.length, 1);
      expect(actions[0], isA<UploadAction>());
    });

    test('both modified local newer', () {
      var local = LocalFileInfo(path: 'file.md', checksum: 'new_local', modifiedAt: '2026-03-15T12:00:00+00:00', size: 100);
      var remote = RemoteFileSnapshot(path: 'file.md', lastModified: 'Mon, 01 Mar 2026 00:00:00 GMT', size: 200);
      var state = SyncState();
      state.files['file.md'] = _makeBase('old_base');

      var actions = computeSyncActions([local], [remote], state);
      expect(actions.length, 1);
      expect(actions[0], isA<ConflictLocalWinsAction>());
    });

    test('both modified remote newer', () {
      var local = LocalFileInfo(path: 'file.md', checksum: 'new_local', modifiedAt: '2026-01-01T00:00:00+00:00', size: 100);
      var remote = RemoteFileSnapshot(path: 'file.md', lastModified: 'Sun, 15 Mar 2026 12:00:00 GMT', size: 200);
      var state = SyncState();
      state.files['file.md'] = _makeBase('old_base');

      var actions = computeSyncActions([local], [remote], state);
      expect(actions.length, 1);
      expect(actions[0], isA<ConflictRemoteWinsAction>());
    });

    test('deleted local modified remote', () {
      var remote = RemoteFileSnapshot(path: 'file.md', lastModified: 'Mon, 01 Jan 2026 00:00:00 GMT', size: 200);
      var state = SyncState();
      state.files['file.md'] = _makeBase('abc123');

      var actions = computeSyncActions([], [remote], state);
      expect(actions.length, 1);
      expect(actions[0], isA<DownloadAction>());
    });

    test('modified local deleted remote', () {
      var local = [_makeLocal('file.md', 'new_checksum')];
      var state = SyncState();
      state.files['file.md'] = _makeBase('old_checksum');

      var actions = computeSyncActions(local, [], state);
      expect(actions.length, 1);
      expect(actions[0], isA<UploadAction>());
    });

    test('both added local newer', () {
      var local = LocalFileInfo(path: 'file.md', checksum: 'local_content', modifiedAt: '2026-03-15T12:00:00+00:00', size: 100);
      var remote = RemoteFileSnapshot(path: 'file.md', lastModified: 'Mon, 01 Jan 2026 00:00:00 GMT', size: 100);
      var state = SyncState();

      var actions = computeSyncActions([local], [remote], state);
      expect(actions.length, 1);
      expect(actions[0], isA<ConflictLocalWinsAction>());
    });

    test('both deleted', () {
      var state = SyncState();
      state.files['file.md'] = _makeBase('abc123');

      var actions = computeSyncActions([], [], state);
      expect(actions, isEmpty);
    });

    test('multiple files mixed', () {
      var local = [
        _makeLocal('keep.md', 'same'),
        _makeLocal('modified.md', 'new'),
        _makeLocal('new_local.md', 'brand_new'),
      ];
      var remote = [
        _makeRemote('keep.md'),
        _makeRemote('modified.md'),
        _makeRemote('new_remote.md'),
      ];
      var state = SyncState();
      state.files['keep.md'] = _makeBase('same');
      state.files['modified.md'] = _makeBase('old');

      var actions = computeSyncActions(local, remote, state);
      expect(actions.length, 3);
      expect(actions.any((a) => a is UploadAction && a.path == 'modified.md'), true);
      expect(actions.any((a) => a is UploadAction && a.path == 'new_local.md'), true);
      expect(actions.any((a) => a is DownloadAction && a.path == 'new_remote.md'), true);
    });
  });

  group('SyncState persistence', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('onyx_sync_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('save and load roundtrip', () {
      var state = SyncState();
      state.lastSync = DateTime.now().toUtc();
      state.recordFile('test.md', 'abc123', '2026-01-01T00:00:00Z', 42);
      state.save(tempDir.path);

      var loaded = SyncState.load(tempDir.path);
      expect(loaded.lastSync, isNotNull);
      expect(loaded.files.length, 1);
      expect(loaded.files['test.md']!.checksum, 'abc123');
      expect(loaded.files['test.md']!.size, 42);
    });

    test('load missing returns default', () {
      var state = SyncState.load(tempDir.path);
      expect(state.lastSync, isNull);
      expect(state.files, isEmpty);
    });
  });

  group('OfflineQueue', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('onyx_queue_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('save and load roundtrip', () {
      var queue = OfflineQueue(operations: [
        QueuedOperation(actionType: 'upload', path: 'test.md', queuedAt: DateTime.now().toUtc()),
      ]);
      queue.save(tempDir.path);
      var loaded = OfflineQueue.load(tempDir.path);
      expect(loaded.operations.length, 1);
      expect(loaded.operations[0].path, 'test.md');
    });

    test('empty queue cleans up file', () {
      var queuePath = '${tempDir.path}/.syncqueue.json';
      var queue = OfflineQueue(operations: [
        QueuedOperation(actionType: 'upload', path: 'test.md', queuedAt: DateTime.now().toUtc()),
      ]);
      queue.save(tempDir.path);
      expect(File(queuePath).existsSync(), true);

      OfflineQueue().save(tempDir.path);
      expect(File(queuePath).existsSync(), false);
    });

    test('merge fresh overrides stale', () {
      var queue = OfflineQueue(operations: [
        QueuedOperation(actionType: 'upload', path: 'file.md', queuedAt: DateTime.now().toUtc()),
      ]);
      var fresh = <SyncAction>[DownloadAction('file.md')];
      var merged = queue.mergeWithActions(fresh);
      expect(merged.length, 1);
      expect(merged[0], isA<DownloadAction>());
    });

    test('merge combines different paths', () {
      var queue = OfflineQueue(operations: [
        QueuedOperation(actionType: 'upload', path: 'a.md', queuedAt: DateTime.now().toUtc()),
      ]);
      var fresh = <SyncAction>[DownloadAction('b.md')];
      var merged = queue.mergeWithActions(fresh);
      expect(merged.length, 2);
    });
  });

  group('Checksum', () {
    test('deterministic', () {
      var c1 = computeChecksum([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
      var c2 = computeChecksum([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
      expect(c1, c2);
      expect(c1, isNotEmpty);
    });

    test('different data different checksums', () {
      var c1 = computeChecksum([104, 101, 108, 108, 111]);
      var c2 = computeChecksum([119, 111, 114, 108, 100]);
      expect(c1, isNot(c2));
    });
  });

  group('File scanning', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('onyx_scan_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('scan local files', () {
      var root = tempDir.path;
      File('$root/.metadata.json').writeAsStringSync('{}');
      Directory('$root/My Tasks').createSync();
      File('$root/My Tasks/.listdata.json').writeAsStringSync('{}');
      File('$root/My Tasks/task1.md').writeAsStringSync('# Task 1');
      File('$root/My Tasks/task2.md').writeAsStringSync('# Task 2');
      File('$root/My Tasks/notes.txt').writeAsStringSync('notes');
      File('$root/.syncstate.json').writeAsStringSync('{}');

      var files = scanLocalFiles(root);
      expect(files.length, 4);
      expect(files.any((f) => f.path == '.metadata.json'), true);
      expect(files.any((f) => f.path == 'My Tasks/.listdata.json'), true);
      expect(files.any((f) => f.path == 'My Tasks/task1.md'), true);
      expect(files.any((f) => f.path == 'My Tasks/task2.md'), true);
      expect(files.any((f) => f.path.contains('notes.txt')), false);
      expect(files.any((f) => f.path.contains('.syncstate.json')), false);
    });
  });

  group('Sync status', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('onyx_status_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('no state', () {
      File('${tempDir.path}/.metadata.json').writeAsStringSync('{}');
      var status = getSyncStatus(tempDir.path);
      expect(status.lastSync, isNull);
      expect(status.trackedFiles, 0);
      expect(status.pendingChanges, 1); // .metadata.json is new
      expect(status.queuedOperations, 0);
    });
  });
}
