import 'dart:io';

import 'package:test/test.dart';
import 'package:onyx_core/onyx_core.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('onyx_config_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('get current workspace none set throws', () {
    var config = AppConfig();
    expect(() => config.getCurrentWorkspace(), throwsA(isA<WorkspaceNotFoundError>()));
  });

  test('get current workspace name points to removed workspace throws', () {
    var config = AppConfig();
    config.addWorkspace('test', WorkspaceConfig(path: '/tmp'));
    config.currentWorkspace = 'test';
    config.workspaces.remove('test');
    expect(() => config.getCurrentWorkspace(), throwsA(isA<WorkspaceNotFoundError>()));
  });

  test('set current workspace nonexistent throws', () {
    var config = AppConfig();
    expect(() => config.setCurrentWorkspace('ghost'), throwsA(isA<WorkspaceNotFoundError>()));
  });

  test('set current workspace valid', () {
    var config = AppConfig();
    config.addWorkspace('real', WorkspaceConfig(path: '/tmp'));
    config.setCurrentWorkspace('real');
    expect(config.currentWorkspace, 'real');
  });

  test('remove current workspace clears current', () {
    var config = AppConfig();
    config.addWorkspace('ws', WorkspaceConfig(path: '/tmp'));
    config.setCurrentWorkspace('ws');
    config.removeWorkspace('ws');
    expect(config.currentWorkspace, isNull);
    expect(config.getWorkspace('ws'), isNull);
  });

  test('remove noncurrent workspace keeps current', () {
    var config = AppConfig();
    config.addWorkspace('a', WorkspaceConfig(path: '/a'));
    config.addWorkspace('b', WorkspaceConfig(path: '/b'));
    config.setCurrentWorkspace('a');
    config.removeWorkspace('b');
    expect(config.currentWorkspace, 'a');
  });

  test('save and load roundtrip', () {
    var configPath = '${tempDir.path}/config.json';
    var config = AppConfig();
    config.addWorkspace('ws1', WorkspaceConfig(path: '/path/one'));
    config.addWorkspace('ws2', WorkspaceConfig(path: '/path/two'));
    config.setCurrentWorkspace('ws1');
    config.saveToFile(configPath);

    var loaded = AppConfig.loadFromFile(configPath);
    expect(loaded.currentWorkspace, 'ws1');
    expect(loaded.workspaces.length, 2);
    expect(loaded.getWorkspace('ws1')!.path, '/path/one');
    expect(loaded.getWorkspace('ws2')!.path, '/path/two');
  });

  test('load missing file returns default', () {
    var config = AppConfig.loadFromFile('/nonexistent/config.json');
    expect(config.workspaces, isEmpty);
    expect(config.currentWorkspace, isNull);
  });

  test('load corrupt file throws', () {
    var configPath = '${tempDir.path}/config.json';
    File(configPath).writeAsStringSync('not valid json {{{');
    expect(() => AppConfig.loadFromFile(configPath), throwsA(isA<SerializationError>()));
  });

  test('save creates parent dirs', () {
    var configPath = '${tempDir.path}/nested/dir/config.json';
    var config = AppConfig();
    config.saveToFile(configPath);
    expect(File(configPath).existsSync(), true);
  });

  test('add workspace overwrites existing', () {
    var config = AppConfig();
    config.addWorkspace('ws', WorkspaceConfig(path: '/old'));
    config.addWorkspace('ws', WorkspaceConfig(path: '/new'));
    expect(config.getWorkspace('ws')!.path, '/new');
    expect(config.workspaces.length, 1);
  });

  test('workspace config with webdav fields roundtrip', () {
    var configPath = '${tempDir.path}/config.json';
    var config = AppConfig();
    var ws = WorkspaceConfig(path: '/tasks');
    ws.webdavUrl = 'https://dav.example.com/tasks';
    ws.lastSync = DateTime.now().toUtc();
    config.addWorkspace('synced', ws);
    config.saveToFile(configPath);

    var loaded = AppConfig.loadFromFile(configPath);
    var loadedWs = loaded.getWorkspace('synced')!;
    expect(loadedWs.webdavUrl, 'https://dav.example.com/tasks');
    expect(loadedWs.lastSync, isNotNull);
  });

  test('backwards compat loading old format', () {
    var configPath = '${tempDir.path}/config.json';
    File(configPath).writeAsStringSync('''
{
  "workspaces": {
    "personal": { "path": "/home/user/tasks" }
  },
  "current_workspace": "personal"
}''');

    var loaded = AppConfig.loadFromFile(configPath);
    var ws = loaded.getWorkspace('personal')!;
    expect(ws.path, '/home/user/tasks');
    expect(ws.webdavUrl, isNull);
    expect(ws.lastSync, isNull);
  });
}
