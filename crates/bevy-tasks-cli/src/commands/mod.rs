pub mod init;
pub mod workspace;
pub mod list;
pub mod task;
pub mod group;
pub mod sync;

use bevy_tasks_core::{AppConfig, TaskRepository};
use anyhow::{Context, Result};
use std::path::PathBuf;

pub fn get_config_path() -> PathBuf {
    AppConfig::get_config_path()
}

pub fn load_config() -> Result<AppConfig> {
    let path = get_config_path();
    AppConfig::load_from_file(&path).context("Failed to load config")
}

pub fn save_config(config: &AppConfig) -> Result<()> {
    let path = get_config_path();
    config.save_to_file(&path).context("Failed to save config")
}

pub fn get_repository(workspace_name: Option<String>) -> Result<(TaskRepository, String)> {
    let config = load_config()?;

    let (name, workspace_config) = if let Some(name) = workspace_name {
        let workspace_config = config.get_workspace(&name)
            .ok_or_else(|| anyhow::anyhow!("Workspace '{}' not found", name))?;
        (name, workspace_config.clone())
    } else {
        let (name, workspace_config) = config.get_current_workspace()
            .context("No workspace set. Use 'bevy-tasks init' to create one.")?;
        (name.clone(), workspace_config.clone())
    };

    let repo = TaskRepository::new(workspace_config.path.clone())
        .context(format!("Failed to open workspace '{}'", name))?;

    Ok((repo, name))
}
