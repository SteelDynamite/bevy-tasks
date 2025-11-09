use crate::error::{Error, Result};
use crate::webdav::WebDavClient;
use chrono::{DateTime, Utc};
use std::fs;
use std::path::{Path, PathBuf};

/// Result of a sync operation
#[derive(Debug, Clone)]
pub struct SyncResult {
    pub uploaded: Vec<String>,
    pub downloaded: Vec<String>,
    pub deleted_local: Vec<String>,
    pub deleted_remote: Vec<String>,
    pub conflicts_resolved: Vec<String>,
    pub unchanged: usize,
}

impl SyncResult {
    pub fn new() -> Self {
        Self {
            uploaded: Vec::new(),
            downloaded: Vec::new(),
            deleted_local: Vec::new(),
            deleted_remote: Vec::new(),
            conflicts_resolved: Vec::new(),
            unchanged: 0,
        }
    }

    pub fn total_changes(&self) -> usize {
        self.uploaded.len()
            + self.downloaded.len()
            + self.deleted_local.len()
            + self.deleted_remote.len()
    }
}

impl Default for SyncResult {
    fn default() -> Self {
        Self::new()
    }
}

/// Status of the sync connection
#[derive(Debug, Clone)]
pub struct SyncStatus {
    pub connected: bool,
    pub last_sync: Option<DateTime<Utc>>,
    pub local_changes: usize,
    pub remote_changes: usize,
    pub webdav_url: String,
}

/// Sync engine for coordinating file synchronization
pub struct SyncEngine {
    local_path: PathBuf,
    webdav_client: WebDavClient,
}

impl SyncEngine {
    /// Create a new sync engine
    pub fn new(local_path: PathBuf, webdav_client: WebDavClient) -> Self {
        Self {
            local_path,
            webdav_client,
        }
    }

    /// Push local changes to the remote server
    pub async fn push(&self) -> Result<SyncResult> {
        let mut result = SyncResult::new();

        // Get all local files recursively
        let local_files = self.get_local_files()?;

        for file_path in local_files {
            let relative_path = file_path
                .strip_prefix(&self.local_path)
                .map_err(|e| Error::Other(format!("Failed to strip prefix: {}", e)))?;

            let relative_path_str = relative_path
                .to_str()
                .ok_or_else(|| Error::Other("Invalid UTF-8 in path".to_string()))?;

            // Read file content
            let content = fs::read(&file_path)?;

            // Upload to WebDAV
            self.webdav_client
                .upload_file(relative_path_str, content)
                .await?;

            result.uploaded.push(relative_path_str.to_string());
        }

        Ok(result)
    }

    /// Pull remote changes to local
    pub async fn pull(&self) -> Result<SyncResult> {
        let mut result = SyncResult::new();

        // List remote files
        // TODO: Implement proper file listing once ListEntity is working
        // For now, we'll return an empty result
        let remote_files: Vec<String> = self.webdav_client.list_files("", 999).await?;

        for file_path in remote_files {
            // Download file
            let content = self.webdav_client.download_file(&file_path).await?;

            // Write to local filesystem
            let local_file_path = self.local_path.join(&file_path);

            // Create parent directories if needed
            if let Some(parent) = local_file_path.parent() {
                fs::create_dir_all(parent)?;
            }

            fs::write(&local_file_path, content)?;

            result.downloaded.push(file_path);
        }

        Ok(result)
    }

    /// Perform bidirectional sync (pull then push)
    pub async fn sync(&self) -> Result<SyncResult> {
        // For now, do a simple pull then push
        // In a more sophisticated implementation, we'd:
        // 1. Compare local and remote files
        // 2. Detect conflicts
        // 3. Apply conflict resolution strategy
        // 4. Sync changes bidirectionally

        let pull_result = self.pull().await?;
        let push_result = self.push().await?;

        Ok(SyncResult {
            uploaded: push_result.uploaded,
            downloaded: pull_result.downloaded,
            deleted_local: pull_result.deleted_local,
            deleted_remote: push_result.deleted_remote,
            conflicts_resolved: Vec::new(),
            unchanged: 0,
        })
    }

    /// Get sync status
    pub async fn status(&self) -> Result<SyncStatus> {
        // Check if we can connect to the server
        let connected = self.webdav_client.exists("").await.unwrap_or(false);

        // Count local changes (simplified - just count all files for now)
        let local_files = self.get_local_files()?;
        let local_changes = local_files.len();

        // Remote changes would require comparing with remote
        let remote_changes = 0;

        Ok(SyncStatus {
            connected,
            last_sync: None, // Would need to be stored somewhere
            local_changes,
            remote_changes,
            webdav_url: String::new(), // Would come from workspace config
        })
    }

    /// Get all local files recursively
    fn get_local_files(&self) -> Result<Vec<PathBuf>> {
        let mut files = Vec::new();
        self.collect_files_recursive(&self.local_path, &mut files)?;
        Ok(files)
    }

    /// Recursively collect files from a directory
    fn collect_files_recursive(&self, dir: &Path, files: &mut Vec<PathBuf>) -> Result<()> {
        if !dir.is_dir() {
            return Ok(());
        }

        for entry in fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            // Skip hidden files and metadata files
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                if name.starts_with('.') {
                    continue;
                }
            }

            if path.is_dir() {
                self.collect_files_recursive(&path, files)?;
            } else {
                files.push(path);
            }
        }

        Ok(())
    }

    /// Compare file timestamps for conflict resolution (last-write-wins)
    #[allow(dead_code)]
    fn compare_timestamps(
        local_modified: DateTime<Utc>,
        remote_modified: DateTime<Utc>,
    ) -> ConflictResolution {
        if local_modified > remote_modified {
            ConflictResolution::UseLocal
        } else if remote_modified > local_modified {
            ConflictResolution::UseRemote
        } else {
            ConflictResolution::NoConflict
        }
    }
}

/// Conflict resolution strategy result
#[derive(Debug, Clone, PartialEq)]
#[allow(dead_code)]
enum ConflictResolution {
    UseLocal,
    UseRemote,
    NoConflict,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_result_total_changes() {
        let mut result = SyncResult::new();
        result.uploaded.push("file1.md".to_string());
        result.downloaded.push("file2.md".to_string());
        result.deleted_local.push("file3.md".to_string());

        assert_eq!(result.total_changes(), 3);
    }

    #[test]
    fn test_conflict_resolution_local_newer() {
        let local = Utc::now();
        let remote = local - chrono::Duration::hours(1);

        assert_eq!(
            SyncEngine::compare_timestamps(local, remote),
            ConflictResolution::UseLocal
        );
    }

    #[test]
    fn test_conflict_resolution_remote_newer() {
        let local = Utc::now();
        let remote = local + chrono::Duration::hours(1);

        assert_eq!(
            SyncEngine::compare_timestamps(local, remote),
            ConflictResolution::UseRemote
        );
    }

    #[test]
    fn test_conflict_resolution_same_time() {
        let time = Utc::now();

        assert_eq!(
            SyncEngine::compare_timestamps(time, time),
            ConflictResolution::NoConflict
        );
    }
}
