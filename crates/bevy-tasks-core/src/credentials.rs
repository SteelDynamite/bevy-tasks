use crate::error::{Error, Result};
use keyring::Entry;
use url::Url;

/// Manages secure credential storage for WebDAV servers using the system keychain
pub struct CredentialManager {
    service_name: String,
}

impl CredentialManager {
    /// Create a new credential manager for bevy-tasks
    pub fn new() -> Self {
        Self {
            service_name: "com.bevy-tasks.webdav".to_string(),
        }
    }

    /// Store WebDAV credentials in the system keychain
    ///
    /// The username is stored as the account, and the password is stored securely.
    /// The server domain is extracted from the URL to create a unique keychain entry.
    pub fn store_credentials(&self, webdav_url: &str, username: &str, password: &str) -> Result<()> {
        let domain = Self::extract_domain(webdav_url)?;
        let key = format!("{}.{}", self.service_name, domain);

        let entry = Entry::new(&key, username)
            .map_err(|e| Error::Other(format!("Failed to create keychain entry: {}", e)))?;

        entry
            .set_password(password)
            .map_err(|e| Error::Other(format!("Failed to store password in keychain: {}", e)))?;

        Ok(())
    }

    /// Retrieve WebDAV credentials from the system keychain
    ///
    /// Returns (username, password) if found
    pub fn get_credentials(&self, webdav_url: &str) -> Result<(String, String)> {
        let _domain = Self::extract_domain(webdav_url)?;

        // First, we need to find the entry. For now, we'll assume the username
        // is stored in the workspace config separately, or we list entries.
        // This is a simplified version - in practice, you might store username separately.

        Err(Error::Other("Credentials retrieval requires username - store username in workspace config".to_string()))
    }

    /// Retrieve credentials with a known username
    pub fn get_credentials_with_username(&self, webdav_url: &str, username: &str) -> Result<String> {
        let domain = Self::extract_domain(webdav_url)?;
        let key = format!("{}.{}", self.service_name, domain);

        let entry = Entry::new(&key, username)
            .map_err(|e| Error::Other(format!("Failed to create keychain entry: {}", e)))?;

        let password = entry
            .get_password()
            .map_err(|e| Error::Other(format!("Failed to retrieve password from keychain: {}", e)))?;

        Ok(password)
    }

    /// Delete stored credentials for a WebDAV server
    pub fn delete_credentials(&self, webdav_url: &str, username: &str) -> Result<()> {
        let domain = Self::extract_domain(webdav_url)?;
        let key = format!("{}.{}", self.service_name, domain);

        let entry = Entry::new(&key, username)
            .map_err(|e| Error::Other(format!("Failed to create keychain entry: {}", e)))?;

        entry
            .delete_credential()
            .map_err(|e| Error::Other(format!("Failed to delete credentials: {}", e)))?;

        Ok(())
    }

    /// Extract domain from WebDAV URL for use as keychain identifier
    fn extract_domain(webdav_url: &str) -> Result<String> {
        let url = Url::parse(webdav_url)
            .map_err(|e| Error::Other(format!("Invalid WebDAV URL: {}", e)))?;

        let domain = url
            .host_str()
            .ok_or_else(|| Error::Other("WebDAV URL has no host".to_string()))?
            .to_string();

        Ok(domain)
    }
}

impl Default for CredentialManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_domain() {
        assert_eq!(
            CredentialManager::extract_domain("https://nextcloud.example.com/remote.php/dav").unwrap(),
            "nextcloud.example.com"
        );

        assert_eq!(
            CredentialManager::extract_domain("https://example.com:8080/webdav").unwrap(),
            "example.com"
        );
    }

    #[test]
    fn test_extract_domain_invalid_url() {
        assert!(CredentialManager::extract_domain("not-a-url").is_err());
    }
}
