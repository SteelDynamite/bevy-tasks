/// Sealed error hierarchy for all Onyx operations.
sealed class OnyxError implements Exception {
  String get message;

  @override
  String toString() => message;
}

class IoError extends OnyxError {
  @override
  final String message;
  IoError(this.message);

  @override
  String toString() => 'IO error: $message';
}

class SerializationError extends OnyxError {
  @override
  final String message;
  SerializationError(this.message);

  @override
  String toString() => 'Serialization error: $message';
}

class NotFoundError extends OnyxError {
  @override
  final String message;
  NotFoundError(this.message);

  @override
  String toString() => 'Not found: $message';
}

class InvalidDataError extends OnyxError {
  @override
  final String message;
  InvalidDataError(this.message);

  @override
  String toString() => 'Invalid data: $message';
}

class WorkspaceNotFoundError extends OnyxError {
  @override
  final String message;
  WorkspaceNotFoundError(this.message);

  @override
  String toString() => 'Workspace not found: $message';
}

class ListNotFoundError extends OnyxError {
  @override
  final String message;
  ListNotFoundError(this.message);

  @override
  String toString() => 'List not found: $message';
}

class TaskNotFoundError extends OnyxError {
  @override
  final String message;
  TaskNotFoundError(this.message);

  @override
  String toString() => 'Task not found: $message';
}

class WebDavError extends OnyxError {
  @override
  final String message;
  WebDavError(this.message);

  @override
  String toString() => 'WebDAV error: $message';
}

class SyncError extends OnyxError {
  @override
  final String message;
  SyncError(this.message);

  @override
  String toString() => 'Sync error: $message';
}

class CredentialError extends OnyxError {
  @override
  final String message;
  CredentialError(this.message);

  @override
  String toString() => 'Credential error: $message';
}
