pub mod group;
pub mod init;
pub mod list;
pub mod task;
pub mod workspace;

use anyhow::Result;
use bevy_tasks_core::{AppConfig, TaskRepository};
use std::path::PathBuf;

/// Get the current workspace repository
pub fn get_current_repo(workspace_name: Option<String>) -> Result<TaskRepository> {
    let mut config = AppConfig::load()?;

    let workspace_path = if let Some(name) = workspace_name {
        config.get_workspace(&name)?.path.clone()
    } else {
        let (_, workspace) = config.get_current_workspace()?;
        workspace.path.clone()
    };

    TaskRepository::new(workspace_path)
}
