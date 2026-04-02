import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'error.dart';

/// Configuration for a single workspace.
class WorkspaceConfig {
  String path;
  String? webdavUrl;
  DateTime? lastSync;

  WorkspaceConfig({required this.path, this.webdavUrl, this.lastSync});

  factory WorkspaceConfig.fromJson(Map<String, dynamic> json) => WorkspaceConfig(
        path: json['path'] as String,
        webdavUrl: json['webdav_url'] as String?,
        lastSync: json['last_sync'] != null ? DateTime.parse(json['last_sync'] as String).toUtc() : null,
      );

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{'path': path};
    if (webdavUrl != null) map['webdav_url'] = webdavUrl;
    if (lastSync != null) {
      // Format without milliseconds to match Rust
      var u = lastSync!.toUtc();
      var y = u.year.toString().padLeft(4, '0');
      var m = u.month.toString().padLeft(2, '0');
      var d = u.day.toString().padLeft(2, '0');
      var h = u.hour.toString().padLeft(2, '0');
      var mi = u.minute.toString().padLeft(2, '0');
      var s = u.second.toString().padLeft(2, '0');
      map['last_sync'] = '$y-$m-${d}T$h:$mi:${s}Z';
    }
    return map;
  }
}

/// Application-level config managing named workspaces. Persisted as JSON.
class AppConfig {
  Map<String, WorkspaceConfig> workspaces;
  String? currentWorkspace;

  AppConfig({Map<String, WorkspaceConfig>? workspaces, this.currentWorkspace})
      : workspaces = workspaces ?? {};

  void addWorkspace(String name, WorkspaceConfig config) {
    workspaces[name] = config;
  }

  WorkspaceConfig? removeWorkspace(String name) {
    if (currentWorkspace == name) currentWorkspace = null;
    return workspaces.remove(name);
  }

  WorkspaceConfig? getWorkspace(String name) => workspaces[name];

  (String, WorkspaceConfig) getCurrentWorkspace() {
    var name = currentWorkspace;
    if (name == null) throw WorkspaceNotFoundError('No current workspace set');
    var config = workspaces[name];
    if (config == null) throw WorkspaceNotFoundError(name);
    return (name, config);
  }

  void setCurrentWorkspace(String name) {
    if (!workspaces.containsKey(name)) throw WorkspaceNotFoundError(name);
    currentWorkspace = name;
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    var wsMap = <String, WorkspaceConfig>{};
    var wsJson = json['workspaces'] as Map<String, dynamic>? ?? {};
    for (var entry in wsJson.entries) {
      wsMap[entry.key] = WorkspaceConfig.fromJson(entry.value as Map<String, dynamic>);
    }
    return AppConfig(
      workspaces: wsMap,
      currentWorkspace: json['current_workspace'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    var wsJson = <String, dynamic>{};
    for (var entry in workspaces.entries) {
      wsJson[entry.key] = entry.value.toJson();
    }
    return {
      'workspaces': wsJson,
      'current_workspace': currentWorkspace,
    };
  }

  /// Load config from a file. Returns default config if file doesn't exist.
  static AppConfig loadFromFile(String filePath) {
    var file = File(filePath);
    if (!file.existsSync()) return AppConfig();
    var content = file.readAsStringSync();
    try {
      return AppConfig.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      throw SerializationError('Failed to parse config: $e');
    }
  }

  /// Save config to a file, creating parent directories if needed.
  void saveToFile(String filePath) {
    var file = File(filePath);
    var parent = file.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
  }

  /// Get the platform-specific default config path.
  /// Pass [overridePath] for Android or testing.
  static String getConfigPath({String? overridePath}) {
    if (overridePath != null) return overridePath;

    if (Platform.isWindows) {
      var appdata = Platform.environment['APPDATA'];
      if (appdata != null) return p.join(appdata, 'onyx', 'config.json');
      return p.join(Platform.environment['USERPROFILE'] ?? '.', 'AppData', 'Roaming', 'onyx', 'config.json');
    }
    if (Platform.isMacOS) {
      var home = Platform.environment['HOME'] ?? '.';
      return p.join(home, 'Library', 'Application Support', 'onyx', 'config.json');
    }
    // Linux and other
    var home = Platform.environment['HOME'] ?? '.';
    return p.join(home, '.config', 'onyx', 'config.json');
  }
}
