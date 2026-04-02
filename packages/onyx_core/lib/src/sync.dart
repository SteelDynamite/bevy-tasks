import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'error.dart';
import 'webdav.dart';

/// Persisted sync state for a workspace, stored as .syncstate.json.
class SyncState {
  DateTime? lastSync;
  Map<String, SyncFileEntry> files;

  SyncState({this.lastSync, Map<String, SyncFileEntry>? files}) : files = files ?? {};

  factory SyncState.fromJson(Map<String, dynamic> json) {
    var filesMap = <String, SyncFileEntry>{};
    var filesJson = json['files'] as Map<String, dynamic>? ?? {};
    for (var entry in filesJson.entries) {
      filesMap[entry.key] = SyncFileEntry.fromJson(entry.value as Map<String, dynamic>);
    }
    return SyncState(
      lastSync: json['last_sync'] != null ? DateTime.parse(json['last_sync'] as String).toUtc() : null,
      files: filesMap,
    );
  }

  Map<String, dynamic> toJson() {
    var filesJson = <String, dynamic>{};
    for (var entry in files.entries) {
      filesJson[entry.key] = entry.value.toJson();
    }
    return {
      'last_sync': lastSync?.toUtc().toIso8601String(),
      'files': filesJson,
    };
  }

  /// Load sync state from a workspace directory. Returns default if missing.
  static SyncState load(String workspacePath) {
    var file = File(p.join(workspacePath, '.syncstate.json'));
    if (!file.existsSync()) return SyncState();
    try {
      var content = file.readAsStringSync();
      return SyncState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return SyncState();
    }
  }

  /// Save sync state to a workspace directory.
  void save(String workspacePath) {
    var file = File(p.join(workspacePath, '.syncstate.json'));
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
  }

  /// Record a file's state after a successful sync action.
  void recordFile(String path, String checksum, String? modifiedAt, int size) {
    files[path] = SyncFileEntry(checksum: checksum, modifiedAt: modifiedAt, size: size);
  }

  /// Remove a file entry from sync state (after deletion).
  void removeFile(String path) => files.remove(path);
}

/// Entry tracking the last-synced state of a single file.
class SyncFileEntry {
  String checksum;
  String? modifiedAt;
  int size;

  SyncFileEntry({required this.checksum, this.modifiedAt, this.size = 0});

  factory SyncFileEntry.fromJson(Map<String, dynamic> json) => SyncFileEntry(
        checksum: json['checksum'] as String,
        modifiedAt: json['modified_at'] as String?,
        size: json['size'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'checksum': checksum,
        'modified_at': modifiedAt,
        'size': size,
      };
}

/// An action to take during sync, computed from the three-way diff.
sealed class SyncAction {
  String get path;
}

class UploadAction extends SyncAction {
  @override
  final String path;
  UploadAction(this.path);

  @override
  bool operator ==(Object other) => other is UploadAction && other.path == path;
  @override
  int get hashCode => path.hashCode ^ 1;
}

class DownloadAction extends SyncAction {
  @override
  final String path;
  DownloadAction(this.path);

  @override
  bool operator ==(Object other) => other is DownloadAction && other.path == path;
  @override
  int get hashCode => path.hashCode ^ 2;
}

class DeleteLocalAction extends SyncAction {
  @override
  final String path;
  DeleteLocalAction(this.path);

  @override
  bool operator ==(Object other) => other is DeleteLocalAction && other.path == path;
  @override
  int get hashCode => path.hashCode ^ 3;
}

class DeleteRemoteAction extends SyncAction {
  @override
  final String path;
  DeleteRemoteAction(this.path);

  @override
  bool operator ==(Object other) => other is DeleteRemoteAction && other.path == path;
  @override
  int get hashCode => path.hashCode ^ 4;
}

class ConflictLocalWinsAction extends SyncAction {
  @override
  final String path;
  ConflictLocalWinsAction(this.path);

  @override
  bool operator ==(Object other) => other is ConflictLocalWinsAction && other.path == path;
  @override
  int get hashCode => path.hashCode ^ 5;
}

class ConflictRemoteWinsAction extends SyncAction {
  @override
  final String path;
  ConflictRemoteWinsAction(this.path);

  @override
  bool operator ==(Object other) => other is ConflictRemoteWinsAction && other.path == path;
  @override
  int get hashCode => path.hashCode ^ 6;
}

/// Result summary of a sync operation.
class SyncResult {
  int uploaded = 0;
  int downloaded = 0;
  int deletedLocal = 0;
  int deletedRemote = 0;
  int conflicts = 0;
  List<String> errors = [];
}

/// Sync direction mode.
enum SyncMode { push, pull, full }

/// Snapshot of a local file's state.
class LocalFileInfo {
  final String path;
  final String checksum;
  final String? modifiedAt;
  final int size;

  LocalFileInfo({required this.path, required this.checksum, this.modifiedAt, this.size = 0});
}

/// Snapshot of a remote file's state (from PROPFIND).
class RemoteFileSnapshot {
  final String path;
  final String? lastModified;
  final int size;

  RemoteFileSnapshot({required this.path, this.lastModified, this.size = 0});
}

/// Compute SHA-256 checksum of data.
String computeChecksum(List<int> data) {
  var digest = sha256.convert(data);
  return digest.toString();
}

/// Check if a filename is a syncable file.
bool _isSyncable(String path) {
  var filename = path.split('/').last;
  return filename.endsWith('.md') || filename == '.listdata.json' || filename == '.metadata.json';
}

/// Scan local workspace files and compute checksums.
List<LocalFileInfo> scanLocalFiles(String workspacePath) {
  var files = <LocalFileInfo>[];
  _scanDirRecursive(workspacePath, workspacePath, files);
  return files;
}

void _scanDirRecursive(String root, String dir, List<LocalFileInfo> files) {
  var directory = Directory(dir);
  for (var entity in directory.listSync()) {
    var relative = p.relative(entity.path, from: root).replaceAll('\\', '/');

    // Skip sync state/queue files
    if (relative == '.syncstate.json' || relative == '.syncqueue.json') continue;

    if (entity is Directory) {
      _scanDirRecursive(root, entity.path, files);
    } else if (entity is File && _isSyncable(relative)) {
      var data = entity.readAsBytesSync();
      var stat = entity.statSync();
      var modified = stat.modified.toUtc().toIso8601String();
      files.add(LocalFileInfo(
        path: relative,
        checksum: computeChecksum(data),
        modifiedAt: modified,
        size: data.length,
      ));
    }
  }
}

/// Determine if local wins based on timestamps. True means local wins.
bool _localWins(String? localModified, String? remoteModified) {
  var localTs = localModified != null ? _parseTimestamp(localModified) : null;
  var remoteTs = remoteModified != null ? _parseTimestamp(remoteModified) : null;
  if (localTs != null && remoteTs != null) return !localTs.isBefore(remoteTs);
  if (localTs != null) return true;
  if (remoteTs != null) return false;
  return true; // Default to local
}

/// Parse a timestamp string (ISO 8601, RFC 2822, or HTTP date format).
DateTime? _parseTimestamp(String s) {
  // Try ISO 8601 / RFC 3339
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {}

  // Try HTTP date format: "Mon, 01 Jan 2026 00:00:00 GMT"
  if (s.endsWith('GMT')) {
    var trimmed = s.substring(0, s.length - 3).trim();
    var commaIdx = trimmed.indexOf(', ');
    if (commaIdx != -1) {
      var datePart = trimmed.substring(commaIdx + 2);
      try {
        return HttpDate.parse(s).toUtc();
      } catch (_) {}
    }
  }

  // Try RFC 2822 via HttpDate
  try {
    return HttpDate.parse(s).toUtc();
  } catch (_) {}

  return null;
}

/// Compute sync actions by comparing local files, remote files, and the last-synced base state.
List<SyncAction> computeSyncActions(
  List<LocalFileInfo> localFiles,
  List<RemoteFileSnapshot> remoteFiles,
  SyncState syncState,
) {
  var localMap = {for (var f in localFiles) f.path: f};
  var remoteMap = {for (var f in remoteFiles) f.path: f};

  var allPaths = <String>{};
  for (var f in localFiles) allPaths.add(f.path);
  for (var f in remoteFiles) allPaths.add(f.path);
  for (var p in syncState.files.keys) allPaths.add(p);

  var actions = <SyncAction>[];

  for (var path in allPaths) {
    var local = localMap[path];
    var remote = remoteMap[path];
    var base = syncState.files[path];

    if (local != null && remote != null && base != null) {
      // Both present, base known
      var localChanged = local.checksum != base.checksum;
      var remoteChanged = remote.size != base.size || remote.lastModified != base.modifiedAt;
      if (!localChanged && !remoteChanged) continue;
      if (localChanged && !remoteChanged) {
        actions.add(UploadAction(path));
      } else if (!localChanged && remoteChanged) {
        actions.add(DownloadAction(path));
      } else {
        // Both modified: last-write-wins
        if (_localWins(local.modifiedAt, remote.lastModified)) {
          actions.add(ConflictLocalWinsAction(path));
        } else {
          actions.add(ConflictRemoteWinsAction(path));
        }
      }
    } else if (local != null && remote == null && base == null) {
      // Added locally
      actions.add(UploadAction(path));
    } else if (local == null && remote != null && base == null) {
      // Added remotely
      actions.add(DownloadAction(path));
    } else if (local != null && remote != null && base == null) {
      // Both added, no base: last-write-wins
      if (_localWins(local.modifiedAt, remote.lastModified)) {
        actions.add(ConflictLocalWinsAction(path));
      } else {
        actions.add(ConflictRemoteWinsAction(path));
      }
    } else if (local != null && remote == null && base != null) {
      // Local present, remote gone, base known: upload (local wins)
      actions.add(UploadAction(path));
    } else if (local == null && remote != null && base != null) {
      // Remote present, local gone, base known
      var remoteChanged = remote.size != base.size || remote.lastModified != base.modifiedAt;
      if (remoteChanged) {
        actions.add(DownloadAction(path));
      } else {
        actions.add(DeleteRemoteAction(path));
      }
    }
    // Both gone (with or without base): skip
  }

  // Sort for deterministic output
  actions.sort((a, b) => a.path.compareTo(b.path));
  return actions;
}

/// Persisted offline operation queue, stored as .syncqueue.json.
class OfflineQueue {
  List<QueuedOperation> operations;

  OfflineQueue({List<QueuedOperation>? operations}) : operations = operations ?? [];

  static OfflineQueue load(String workspacePath) {
    var file = File(p.join(workspacePath, '.syncqueue.json'));
    if (!file.existsSync()) return OfflineQueue();
    try {
      var content = file.readAsStringSync();
      var json = jsonDecode(content) as Map<String, dynamic>;
      var ops = (json['operations'] as List<dynamic>?)
              ?.map((e) => QueuedOperation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return OfflineQueue(operations: ops);
    } catch (_) {
      return OfflineQueue();
    }
  }

  void save(String workspacePath) {
    var queuePath = p.join(workspacePath, '.syncqueue.json');
    if (operations.isEmpty) {
      var file = File(queuePath);
      if (file.existsSync()) file.deleteSync();
      return;
    }
    var json = {'operations': operations.map((o) => o.toJson()).toList()};
    File(queuePath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// Merge queued operations with fresh actions, deduplicating by path.
  List<SyncAction> mergeWithActions(List<SyncAction> freshActions) {
    var resultMap = <String, SyncAction>{};
    // Queued operations first (lower priority)
    for (var op in operations) {
      var action = _queuedOpToAction(op);
      if (action != null) resultMap[op.path] = action;
    }
    // Fresh actions override
    for (var action in freshActions) {
      resultMap[action.path] = action;
    }
    var result = resultMap.values.toList();
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }
}

/// A queued sync operation that failed to execute.
class QueuedOperation {
  String actionType;
  String path;
  DateTime queuedAt;

  QueuedOperation({required this.actionType, required this.path, required this.queuedAt});

  factory QueuedOperation.fromJson(Map<String, dynamic> json) => QueuedOperation(
        actionType: json['action_type'] as String,
        path: json['path'] as String,
        queuedAt: DateTime.parse(json['queued_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'action_type': actionType,
        'path': path,
        'queued_at': queuedAt.toUtc().toIso8601String(),
      };
}

SyncAction? _queuedOpToAction(QueuedOperation op) {
  return switch (op.actionType) {
    'upload' => UploadAction(op.path),
    'download' => DownloadAction(op.path),
    'delete_local' => DeleteLocalAction(op.path),
    'delete_remote' => DeleteRemoteAction(op.path),
    'conflict_local_wins' => ConflictLocalWinsAction(op.path),
    'conflict_remote_wins' => ConflictRemoteWinsAction(op.path),
    _ => null,
  };
}

QueuedOperation _actionToQueuedOp(SyncAction action) {
  var actionType = switch (action) {
    UploadAction() => 'upload',
    DownloadAction() => 'download',
    DeleteLocalAction() => 'delete_local',
    DeleteRemoteAction() => 'delete_remote',
    ConflictLocalWinsAction() => 'conflict_local_wins',
    ConflictRemoteWinsAction() => 'conflict_remote_wins',
  };
  return QueuedOperation(actionType: actionType, path: action.path, queuedAt: DateTime.now().toUtc());
}

/// Callback type for sync progress reporting.
typedef ProgressCallback = void Function(String message);

/// Execute a full sync between a local workspace and a remote WebDAV server.
Future<SyncResult> syncWorkspace({
  required String workspacePath,
  required String webdavUrl,
  required String username,
  required String password,
  required SyncMode mode,
  ProgressCallback? onProgress,
}) async {
  var client = WebDavClient(webdavUrl, username, password);
  var syncState = SyncState.load(workspacePath);
  var queue = OfflineQueue.load(workspacePath);
  var result = SyncResult();

  void report(String msg) => onProgress?.call(msg);

  // Ensure remote root exists
  await client.testConnection();

  // Scan local files
  var localFiles = scanLocalFiles(workspacePath);

  // Scan remote files
  List<RemoteFileSnapshot> remoteFiles;
  try {
    remoteFiles = await _scanRemoteFiles(client, '');
  } catch (e) {
    result.errors.add('Failed to scan remote: $e');
    return result;
  }

  // Compute actions from three-way diff
  var freshActions = computeSyncActions(localFiles, remoteFiles, syncState);
  var allActions = queue.mergeWithActions(freshActions);

  // Filter by sync mode
  var actions = allActions.where((a) => switch (mode) {
        SyncMode.full => true,
        SyncMode.push => a is UploadAction || a is DeleteRemoteAction || a is ConflictLocalWinsAction,
        SyncMode.pull => a is DownloadAction || a is DeleteLocalAction || a is ConflictRemoteWinsAction,
      }).toList();

  // Execute actions, collecting failures for the queue
  var failedActions = <SyncAction>[];

  for (var action in actions) {
    try {
      await _executeAction(client, workspacePath, action, syncState, report);
      switch (action) {
        case UploadAction() || ConflictLocalWinsAction():
          result.uploaded++;
        case DownloadAction() || ConflictRemoteWinsAction():
          result.downloaded++;
        case DeleteLocalAction():
          result.deletedLocal++;
        case DeleteRemoteAction():
          result.deletedRemote++;
      }
    } catch (e) {
      var msg = 'Failed ${action.path}: $e';
      report('  ! $msg');
      result.errors.add(msg);
      if (action is UploadAction || action is DownloadAction || action is ConflictLocalWinsAction || action is ConflictRemoteWinsAction) {
        result.conflicts++;
      }
      failedActions.add(action);
    }
  }

  // Save queue with remaining failed actions
  var newQueue = OfflineQueue(operations: failedActions.map(_actionToQueuedOp).toList());
  newQueue.save(workspacePath);

  // Update sync state timestamp
  syncState.lastSync = DateTime.now().toUtc();
  syncState.save(workspacePath);

  return result;
}

/// Execute a single sync action.
Future<void> _executeAction(
  WebDavClient client,
  String workspacePath,
  SyncAction action,
  SyncState syncState,
  void Function(String) report,
) async {
  switch (action) {
    case UploadAction(:var path) || ConflictLocalWinsAction(:var path):
      var localPath = p.join(workspacePath, path.replaceAll('/', Platform.pathSeparator));
      var data = File(localPath).readAsBytesSync();
      var checksum = computeChecksum(data);

      var parent = _pathParent(path);
      if (parent != null) await client.ensureDir(parent);

      report('  ^ Uploading $path');
      await client.putFile(path, data);

      var modified = File(localPath).statSync().modified.toUtc().toIso8601String();
      syncState.recordFile(path, checksum, modified, data.length);

    case DownloadAction(:var path) || ConflictRemoteWinsAction(:var path):
      report('  v Downloading $path');
      var data = await client.getFile(path);
      var checksum = computeChecksum(data);

      var localPath = p.join(workspacePath, path.replaceAll('/', Platform.pathSeparator));
      var parentDir = File(localPath).parent;
      if (!parentDir.existsSync()) parentDir.createSync(recursive: true);
      File(localPath).writeAsBytesSync(data);

      var modified = File(localPath).statSync().modified.toUtc().toIso8601String();
      syncState.recordFile(path, checksum, modified, data.length);

    case DeleteLocalAction(:var path):
      report('  x Deleting local $path');
      var localPath = p.join(workspacePath, path.replaceAll('/', Platform.pathSeparator));
      var file = File(localPath);
      if (file.existsSync()) file.deleteSync();
      syncState.removeFile(path);

    case DeleteRemoteAction(:var path):
      report('  x Deleting remote $path');
      await client.deleteFile(path);
      syncState.removeFile(path);
  }
}

/// Recursively scan remote files via PROPFIND.
Future<List<RemoteFileSnapshot>> _scanRemoteFiles(WebDavClient client, String basePath) async {
  var result = <RemoteFileSnapshot>[];
  var entries = await client.listFiles(basePath);

  for (var entry in entries) {
    var fullPath = basePath.isEmpty ? entry.path : '${basePath.replaceAll(RegExp(r'/+$'), '')}/${entry.path}';
    if (entry.isDir) {
      var subEntries = await _scanRemoteFiles(client, fullPath);
      result.addAll(subEntries);
    } else if (_isSyncable(fullPath)) {
      result.add(RemoteFileSnapshot(
        path: fullPath,
        lastModified: entry.lastModified,
        size: entry.contentLength,
      ));
    }
  }

  return result;
}

/// Get the parent path of a sync path.
String? _pathParent(String path) {
  var idx = path.lastIndexOf('/');
  return idx != -1 ? path.substring(0, idx) : null;
}

/// Summary of sync status for display.
class SyncStatusInfo {
  final DateTime? lastSync;
  final int trackedFiles;
  final int pendingChanges;
  final int queuedOperations;

  SyncStatusInfo({this.lastSync, this.trackedFiles = 0, this.pendingChanges = 0, this.queuedOperations = 0});
}

/// Get sync status information for display.
SyncStatusInfo getSyncStatus(String workspacePath) {
  var syncState = SyncState.load(workspacePath);
  var queue = OfflineQueue.load(workspacePath);
  var localFiles = scanLocalFiles(workspacePath);

  var pendingChanges = 0;
  for (var file in localFiles) {
    var base = syncState.files[file.path];
    if (base == null || file.checksum != base.checksum) pendingChanges++;
  }
  // Files in base that are now missing locally
  for (var path in syncState.files.keys) {
    if (!localFiles.any((f) => f.path == path)) pendingChanges++;
  }

  return SyncStatusInfo(
    lastSync: syncState.lastSync,
    trackedFiles: syncState.files.length,
    pendingChanges: pendingChanges,
    queuedOperations: queue.operations.length,
  );
}
