use std::collections::HashMap;
use std::path::PathBuf;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
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
