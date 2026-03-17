use std::collections::HashMap;
use std::path::PathBuf;
use serde::{Deserialize, Serialize};
use crate::error::{Error, Result};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkspaceConfig {
    pub path: PathBuf,
}

impl WorkspaceConfig {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AppConfig {
    pub workspaces: HashMap<String, WorkspaceConfig>,
    pub current_workspace: Option<String>,
}

impl AppConfig {
    pub fn new() -> Self {
        Self {
            workspaces: HashMap::new(),
            current_workspace: None,
        }
    }

    pub fn add_workspace(&mut self, name: String, config: WorkspaceConfig) {
        self.workspaces.insert(name, config);
    }

    pub fn remove_workspace(&mut self, name: &str) -> Option<WorkspaceConfig> {
        if self.current_workspace.as_deref() == Some(name) {
            self.current_workspace = None;
        }
        self.workspaces.remove(name)
    }

    pub fn get_workspace(&self, name: &str) -> Option<&WorkspaceConfig> {
        self.workspaces.get(name)
    }

    pub fn get_current_workspace(&self) -> Result<(&String, &WorkspaceConfig)> {
        let name = self.current_workspace.as_ref()
            .ok_or_else(|| Error::WorkspaceNotFound("No current workspace set".to_string()))?;
        let config = self.workspaces.get(name)
            .ok_or_else(|| Error::WorkspaceNotFound(name.clone()))?;
        Ok((name, config))
    }

    pub fn set_current_workspace(&mut self, name: String) -> Result<()> {
        if !self.workspaces.contains_key(&name) {
            return Err(Error::WorkspaceNotFound(name));
        }
        self.current_workspace = Some(name);
        Ok(())
    }

    pub fn load_from_file(path: &PathBuf) -> Result<Self> {
        if !path.exists() {
            return Ok(Self::new());
        }
        let content = std::fs::read_to_string(path)?;
        let config = serde_json::from_str(&content)?;
        Ok(config)
    }

    pub fn save_to_file(&self, path: &PathBuf) -> Result<()> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(&self)?;
        std::fs::write(path, content)?;
        Ok(())
    }

    pub fn get_config_path() -> PathBuf {
        let config_dir = directories::ProjectDirs::from("", "", "bevy-tasks")
            .expect("Failed to determine config directory");
        config_dir.config_dir().join("config.json")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_get_current_workspace_none_set() {
        let config = AppConfig::new();
        let result = config.get_current_workspace();
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), Error::WorkspaceNotFound(_)));
    }

    #[test]
    fn test_get_current_workspace_name_points_to_removed_workspace() {
        let mut config = AppConfig::new();
        config.add_workspace("test".to_string(), WorkspaceConfig::new(PathBuf::from("/tmp")));
        config.current_workspace = Some("test".to_string());
        config.workspaces.remove("test");

        let result = config.get_current_workspace();
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), Error::WorkspaceNotFound(_)));
    }

    #[test]
    fn test_set_current_workspace_nonexistent() {
        let mut config = AppConfig::new();
        let result = config.set_current_workspace("ghost".to_string());
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), Error::WorkspaceNotFound(_)));
    }

    #[test]
    fn test_set_current_workspace_valid() {
        let mut config = AppConfig::new();
        config.add_workspace("real".to_string(), WorkspaceConfig::new(PathBuf::from("/tmp")));
        assert!(config.set_current_workspace("real".to_string()).is_ok());
        assert_eq!(config.current_workspace.as_deref(), Some("real"));
    }

    #[test]
    fn test_remove_current_workspace_clears_current() {
        let mut config = AppConfig::new();
        config.add_workspace("ws".to_string(), WorkspaceConfig::new(PathBuf::from("/tmp")));
        config.set_current_workspace("ws".to_string()).unwrap();

        config.remove_workspace("ws");
        assert!(config.current_workspace.is_none());
        assert!(config.get_workspace("ws").is_none());
    }

    #[test]
    fn test_remove_noncurrent_workspace_keeps_current() {
        let mut config = AppConfig::new();
        config.add_workspace("a".to_string(), WorkspaceConfig::new(PathBuf::from("/a")));
        config.add_workspace("b".to_string(), WorkspaceConfig::new(PathBuf::from("/b")));
        config.set_current_workspace("a".to_string()).unwrap();

        config.remove_workspace("b");
        assert_eq!(config.current_workspace.as_deref(), Some("a"));
    }

    #[test]
    fn test_save_and_load_roundtrip() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");

        let mut config = AppConfig::new();
        config.add_workspace("ws1".to_string(), WorkspaceConfig::new(PathBuf::from("/path/one")));
        config.add_workspace("ws2".to_string(), WorkspaceConfig::new(PathBuf::from("/path/two")));
        config.set_current_workspace("ws1".to_string()).unwrap();
        config.save_to_file(&config_path).unwrap();

        let loaded = AppConfig::load_from_file(&config_path).unwrap();
        assert_eq!(loaded.current_workspace.as_deref(), Some("ws1"));
        assert_eq!(loaded.workspaces.len(), 2);
        assert_eq!(loaded.get_workspace("ws1").unwrap().path, PathBuf::from("/path/one"));
        assert_eq!(loaded.get_workspace("ws2").unwrap().path, PathBuf::from("/path/two"));
    }

    #[test]
    fn test_load_missing_file_returns_default() {
        let config = AppConfig::load_from_file(&PathBuf::from("/nonexistent/config.json")).unwrap();
        assert!(config.workspaces.is_empty());
        assert!(config.current_workspace.is_none());
    }

    #[test]
    fn test_load_corrupt_file() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        std::fs::write(&config_path, "not valid json {{{").unwrap();

        let result = AppConfig::load_from_file(&config_path);
        assert!(result.is_err());
    }

    #[test]
    fn test_save_creates_parent_dirs() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("nested").join("dir").join("config.json");

        let config = AppConfig::new();
        assert!(config.save_to_file(&config_path).is_ok());
        assert!(config_path.exists());
    }

    #[test]
    fn test_add_workspace_overwrites_existing() {
        let mut config = AppConfig::new();
        config.add_workspace("ws".to_string(), WorkspaceConfig::new(PathBuf::from("/old")));
        config.add_workspace("ws".to_string(), WorkspaceConfig::new(PathBuf::from("/new")));

        assert_eq!(config.get_workspace("ws").unwrap().path, PathBuf::from("/new"));
        assert_eq!(config.workspaces.len(), 1);
    }
}
