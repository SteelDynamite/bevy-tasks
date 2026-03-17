use anyhow::{Context, Result};
use bevy_tasks_core::{AppConfig, TaskRepository, WorkspaceConfig};
use std::path::PathBuf;
use colored::*;
use crate::output;
use crate::commands::{load_config, save_config};

pub fn add(name: String, path: String) -> Result<()> {
    let path_buf = PathBuf::from(path);
    let path_buf = if path_buf.is_relative() {
        std::env::current_dir()?.join(path_buf)
    } else {
        path_buf
    };

    // Initialize the repository
    let mut repo = TaskRepository::init(path_buf.clone())
        .context("Failed to initialize tasks folder")?;

    // Create default list
    repo.create_list("My Tasks".to_string())
        .context("Failed to create default list")?;

    // Load config
    let mut config = load_config()?;

    // Check if workspace already exists
    if config.get_workspace(&name).is_some() {
        anyhow::bail!("Workspace '{}' already exists", name);
    }

    // Add workspace
    config.add_workspace(name.clone(), WorkspaceConfig::new(path_buf.clone()));

    // Save config
    save_config(&config)?;

    output::success(&format!("Added workspace \"{}\" at {:?}", name, path_buf));
    output::success("Created default list \"My Tasks\"");

    Ok(())
}

pub fn list() -> Result<()> {
    let config = load_config()?;

    if config.workspaces.is_empty() {
        println!("No workspaces configured. Use 'bevy-tasks init' to create one.");
        return Ok(());
    }

    let current = config.current_workspace.as_deref();

    for (name, workspace_config) in &config.workspaces {
        let marker = if Some(name.as_str()) == current {
            " (current)".green()
        } else {
            "".normal()
        };
        println!("  {}: {:?}{}", name, workspace_config.path, marker);
    }

    Ok(())
}

pub fn switch(name: String) -> Result<()> {
    let mut config = load_config()?;

    // Verify workspace exists
    if config.get_workspace(&name).is_none() {
        anyhow::bail!("Workspace '{}' not found", name);
    }

    config.set_current_workspace(name.clone())?;
    save_config(&config)?;

    output::success(&format!("Switched to workspace \"{}\"", name));

    Ok(())
}

pub fn remove(name: String) -> Result<()> {
    let mut config = load_config()?;

    // Verify workspace exists
    if config.get_workspace(&name).is_none() {
        anyhow::bail!("Workspace '{}' not found", name);
    }

    // Confirm
    output::warning("This will delete workspace config (files remain on disk)");
    print!("Continue? (y/n): ");
    use std::io::{self, Write};
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    if input.trim().to_lowercase() != "y" {
        println!("Cancelled");
        return Ok(());
    }

    config.remove_workspace(&name);
    save_config(&config)?;

    output::success(&format!("Removed workspace \"{}\"", name));

    Ok(())
}

pub fn retarget(name: String, path: String) -> Result<()> {
    let path_buf = PathBuf::from(path);
    let path_buf = if path_buf.is_relative() {
        std::env::current_dir()?.join(path_buf)
    } else {
        path_buf
    };

    let mut config = load_config()?;

    // Verify workspace exists
    if config.get_workspace(&name).is_none() {
        anyhow::bail!("Workspace '{}' not found", name);
    }

    // Update path
    config.add_workspace(name.clone(), WorkspaceConfig::new(path_buf.clone()));
    save_config(&config)?;

    output::success(&format!("Workspace \"{}\" now points to {:?}", name, path_buf));

    Ok(())
}

pub fn migrate(name: String, new_path: String) -> Result<()> {
    let new_path_buf = PathBuf::from(new_path);
    let new_path_buf = if new_path_buf.is_relative() {
        std::env::current_dir()?.join(new_path_buf)
    } else {
        new_path_buf
    };

    let mut config = load_config()?;

    // Get current workspace config
    let old_path = config.get_workspace(&name)
        .ok_or_else(|| anyhow::anyhow!("Workspace '{}' not found", name))?
        .path.clone();

    // Confirm
    output::warning(&format!("This will move all files from {:?} to {:?}", old_path, new_path_buf));
    print!("Continue? (y/n): ");
    use std::io::{self, Write};
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    if input.trim().to_lowercase() != "y" {
        println!("Cancelled");
        return Ok(());
    }

    // Create destination directory
    std::fs::create_dir_all(&new_path_buf)?;

    // Move files
    println!("Moving files...");
    let entries = std::fs::read_dir(&old_path)?;
    let mut count = 0;

    for entry in entries {
        let entry = entry?;
        let file_name = entry.file_name();
        let dest = new_path_buf.join(&file_name);

        if entry.path().is_dir() {
            let mut options = fs_extra::dir::CopyOptions::new();
            options.copy_inside = true;
            fs_extra::dir::move_dir(entry.path(), &new_path_buf, &options)?;
            println!("  Moved {:?}/", file_name);
        } else {
            std::fs::rename(entry.path(), dest)?;
            println!("  Moved {:?}", file_name);
        }
        count += 1;
    }

    // Remove old directory if empty
    if old_path.read_dir()?.next().is_none() {
        std::fs::remove_dir(&old_path)?;
    }

    // Update config
    config.add_workspace(name.clone(), WorkspaceConfig::new(new_path_buf.clone()));
    save_config(&config)?;

    output::success(&format!("Migrated {} items to {:?}", count, new_path_buf));
    output::success(&format!("Workspace \"{}\" now points to {:?}", name, new_path_buf));

    Ok(())
}
