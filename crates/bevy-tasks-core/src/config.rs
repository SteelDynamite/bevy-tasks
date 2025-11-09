use crate::error::{Error, Result};
use chrono::{DateTime, Utc};
use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// Configuration for a single workspace
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkspaceConfig {
    pub path: PathBuf,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub webdav_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_sync: Option<DateTime<Utc>>,
}

/// Application configuration supporting multiple workspaces
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub workspaces: HashMap<String, WorkspaceConfig>,
    pub current_workspace: Option<String>,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            workspaces: HashMap::new(),
            current_workspace: None,
        }
    }
}

impl AppConfig {
    /// Get the config file path for the current platform
    pub fn config_path() -> Result<PathBuf> {
        let proj_dirs = ProjectDirs::from("com", "bevy-tasks", "bevy-tasks")
            .ok_or_else(|| Error::PathError("Could not determine config directory".to_string()))?;

        let config_dir = proj_dirs.config_dir();
        Ok(config_dir.join("config.json"))
    }

    /// Load config from disk, or create default if it doesn't exist
    pub fn load() -> Result<Self> {
        let config_path = Self::config_path()?;

        if !config_path.exists() {
            return Ok(Self::default());
        }

        let contents = fs::read_to_string(&config_path)?;
        let config: AppConfig = serde_json::from_str(&contents)?;
        Ok(config)
    }

    /// Save config to disk
    pub fn save(&self) -> Result<()> {
        let config_path = Self::config_path()?;

        // Create parent directory if it doesn't exist
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let contents = serde_json::to_string_pretty(self)?;
        fs::write(&config_path, contents)?;
        Ok(())
    }

    /// Add a new workspace
    pub fn add_workspace(&mut self, name: String, path: PathBuf) -> Result<()> {
        if self.workspaces.contains_key(&name) {
            return Err(Error::WorkspaceAlreadyExists(name));
        }

        self.workspaces.insert(
            name.clone(),
            WorkspaceConfig {
                path,
                webdav_url: None,
                last_sync: None,
            },
        );

        // Set as current if it's the first workspace
        if self.current_workspace.is_none() {
            self.current_workspace = Some(name);
        }

        Ok(())
    }

    /// Remove a workspace
    pub fn remove_workspace(&mut self, name: &str) -> Result<()> {
        if !self.workspaces.contains_key(name) {
            return Err(Error::WorkspaceNotFound(name.to_string()));
        }

        // Don't allow removing current workspace
        if self.current_workspace.as_deref() == Some(name) {
            return Err(Error::CannotRemoveCurrentWorkspace);
        }

        self.workspaces.remove(name);
        Ok(())
    }

    /// Switch to a different workspace
    pub fn switch_workspace(&mut self, name: &str) -> Result<()> {
        if !self.workspaces.contains_key(name) {
            return Err(Error::WorkspaceNotFound(name.to_string()));
        }

        self.current_workspace = Some(name.to_string());
        Ok(())
    }

    /// Get the current workspace config
    pub fn get_current_workspace(&self) -> Result<(&str, &WorkspaceConfig)> {
        let name = self
            .current_workspace
            .as_ref()
            .ok_or(Error::NoCurrentWorkspace)?;

        let config = self
            .workspaces
            .get(name)
            .ok_or_else(|| Error::WorkspaceNotFound(name.clone()))?;

        Ok((name, config))
    }

    /// Get a workspace by name
    pub fn get_workspace(&self, name: &str) -> Result<&WorkspaceConfig> {
        self.workspaces
            .get(name)
            .ok_or_else(|| Error::WorkspaceNotFound(name.to_string()))
    }

    /// Update the path for a workspace
    pub fn update_workspace_path(&mut self, name: &str, new_path: PathBuf) -> Result<()> {
        let workspace = self
            .workspaces
            .get_mut(name)
            .ok_or_else(|| Error::WorkspaceNotFound(name.to_string()))?;

        workspace.path = new_path;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_add_workspace() {
        let mut config = AppConfig::default();
        let temp_dir = TempDir::new().unwrap();

        config
            .add_workspace("test".to_string(), temp_dir.path().to_path_buf())
            .unwrap();

        assert_eq!(config.workspaces.len(), 1);
        assert_eq!(config.current_workspace, Some("test".to_string()));
    }

    #[test]
    fn test_switch_workspace() {
        let mut config = AppConfig::default();
        let temp_dir1 = TempDir::new().unwrap();
        let temp_dir2 = TempDir::new().unwrap();

        config
            .add_workspace("test1".to_string(), temp_dir1.path().to_path_buf())
            .unwrap();
        config
            .add_workspace("test2".to_string(), temp_dir2.path().to_path_buf())
            .unwrap();

        config.switch_workspace("test2").unwrap();
        assert_eq!(config.current_workspace, Some("test2".to_string()));
    }

    #[test]
    fn test_remove_workspace() {
        let mut config = AppConfig::default();
        let temp_dir1 = TempDir::new().unwrap();
        let temp_dir2 = TempDir::new().unwrap();

        config
            .add_workspace("test1".to_string(), temp_dir1.path().to_path_buf())
            .unwrap();
        config
            .add_workspace("test2".to_string(), temp_dir2.path().to_path_buf())
            .unwrap();

        // Should fail - can't remove current workspace
        assert!(config.remove_workspace("test1").is_err());

        // Switch and try again
        config.switch_workspace("test2").unwrap();
        config.remove_workspace("test1").unwrap();
        assert_eq!(config.workspaces.len(), 1);
    }
}
