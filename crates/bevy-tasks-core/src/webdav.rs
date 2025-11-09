use crate::error::{Error, Result};
use reqwest_dav::{Auth, Client, ClientBuilder, Depth};

/// WebDAV client wrapper for syncing task files
pub struct WebDavClient {
    client: Client,
    base_path: String,
}

impl WebDavClient {
    /// Create a new WebDAV client
    ///
    /// # Arguments
    /// * `host` - WebDAV server URL (e.g., "https://nextcloud.example.com")
    /// * `username` - WebDAV username
    /// * `password` - WebDAV password
    /// * `base_path` - Base path on the server (e.g., "/remote.php/dav/files/username/Tasks")
    pub fn new(host: &str, username: &str, password: &str, base_path: &str) -> Result<Self> {
        let client = ClientBuilder::new()
            .set_host(host.to_string())
            .set_auth(Auth::Basic(username.to_owned(), password.to_owned()))
            .build()
            .map_err(|e| Error::Other(format!("Failed to build WebDAV client: {}", e)))?;

        Ok(Self {
            client,
            base_path: base_path.to_string(),
        })
    }

    /// List files and directories at a path
    ///
    /// Returns a list of file paths (as returned by WebDAV server)
    pub async fn list_files(&self, relative_path: &str, depth: u32) -> Result<Vec<String>> {
        let full_path = self.join_path(relative_path);

        let depth = match depth {
            0 => Depth::Number(0),
            1 => Depth::Number(1),
            _ => Depth::Infinity,
        };

        let entities = self
            .client
            .list(&full_path, depth)
            .await
            .map_err(|e| Error::Other(format!("Failed to list WebDAV files: {}", e)))?;

        // For now, just serialize to get the data - we'll parse it properly later
        let _json = serde_json::to_string(&entities)
            .map_err(|e| Error::Other(format!("Failed to serialize list result: {}", e)))?;

        // Just return empty for now - this is a placeholder that we'll improve
        // TODO: Parse ListEntity structure properly once we understand its fields
        Ok(vec![])
    }

    /// Upload a file to the WebDAV server
    ///
    /// # Arguments
    /// * `relative_path` - Path relative to base path
    /// * `content` - File content as bytes
    pub async fn upload_file(&self, relative_path: &str, content: Vec<u8>) -> Result<()> {
        let full_path = self.join_path(relative_path);

        self.client
            .put(&full_path, content)
            .await
            .map_err(|e| Error::Other(format!("Failed to upload file to WebDAV: {}", e)))?;

        Ok(())
    }

    /// Download a file from the WebDAV server
    ///
    /// Returns the file content as bytes
    pub async fn download_file(&self, relative_path: &str) -> Result<Vec<u8>> {
        let full_path = self.join_path(relative_path);

        let response = self
            .client
            .get(&full_path)
            .await
            .map_err(|e| Error::Other(format!("Failed to download file from WebDAV: {}", e)))?;

        // Extract bytes from response
        let bytes = response
            .bytes()
            .await
            .map_err(|e| Error::Other(format!("Failed to read response bytes: {}", e)))?;

        Ok(bytes.to_vec())
    }

    /// Delete a file from the WebDAV server
    pub async fn delete_file(&self, relative_path: &str) -> Result<()> {
        let full_path = self.join_path(relative_path);

        self.client
            .delete(&full_path)
            .await
            .map_err(|e| Error::Other(format!("Failed to delete file from WebDAV: {}", e)))?;

        Ok(())
    }

    /// Create a directory on the WebDAV server
    pub async fn create_directory(&self, relative_path: &str) -> Result<()> {
        let full_path = self.join_path(relative_path);

        self.client
            .mkcol(&full_path)
            .await
            .map_err(|e| Error::Other(format!("Failed to create directory on WebDAV: {}", e)))?;

        Ok(())
    }

    /// Check if a file or directory exists
    pub async fn exists(&self, relative_path: &str) -> Result<bool> {
        let full_path = self.join_path(relative_path);

        // Try to list with depth 0 - if it succeeds, the path exists
        match self.client.list(&full_path, Depth::Number(0)).await {
            Ok(_) => Ok(true),
            Err(_) => Ok(false),
        }
    }

    /// Join base path with relative path
    fn join_path(&self, relative_path: &str) -> String {
        let relative_path = relative_path.trim_start_matches('/');
        if self.base_path.is_empty() {
            format!("/{}", relative_path)
        } else {
            format!("{}/{}", self.base_path.trim_end_matches('/'), relative_path)
        }
    }

}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_join_path() {
        let client = WebDavClient {
            client: ClientBuilder::new()
                .set_host("https://example.com".to_string())
                .build()
                .unwrap(),
            base_path: "/remote.php/dav/files/user/Tasks".to_string(),
        };

        assert_eq!(
            client.join_path("My Tasks/task1.md"),
            "/remote.php/dav/files/user/Tasks/My Tasks/task1.md"
        );

        assert_eq!(
            client.join_path("/My Tasks/task1.md"),
            "/remote.php/dav/files/user/Tasks/My Tasks/task1.md"
        );
    }

    #[test]
    fn test_join_path_empty_base() {
        let client = WebDavClient {
            client: ClientBuilder::new()
                .set_host("https://example.com".to_string())
                .build()
                .unwrap(),
            base_path: "".to_string(),
        };

        assert_eq!(client.join_path("tasks/task1.md"), "/tasks/task1.md");
    }
}
