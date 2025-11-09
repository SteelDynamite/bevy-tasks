use anyhow::Result;
use bevy_tasks_core::{AppConfig, TaskRepository};
use colored::*;
use std::path::PathBuf;

pub fn execute(path: PathBuf, name: String) -> Result<()> {
    // Initialize the repository
    TaskRepository::init(path.clone())?;

    // Load or create app config
    let mut config = AppConfig::load()?;

    // Add workspace
    config.add_workspace(name.clone(), path.clone())?;

    // Save config
    config.save()?;

    println!("{} Initialized workspace \"{}\" at {}",
        "✓".green(),
        name.bold(),
        path.display());
    println!("{} Created default list \"My Tasks\"", "✓".green());
    println!("{} Set \"{}\" as current workspace", "✓".green(), name.bold());

    Ok(())
}
