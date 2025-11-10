use anyhow::Result;
use bevy_tasks_core::{AppConfig, TaskRepository};
use colored::*;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;

pub fn add(name: String, path: PathBuf) -> Result<()> {
    // Initialize the repository at the path
    TaskRepository::init(path.clone())?;

    // Load config
    let mut config = AppConfig::load()?;

    // Add workspace
    config.add_workspace(name.clone(), path.clone())?;

    // Save config
    config.save()?;

    println!(
        "{} Added workspace \"{}\" at {}",
        "✓".green(),
        name.bold(),
        path.display()
    );
    println!("{} Created default list \"My Tasks\"", "✓".green());

    Ok(())
}

pub fn list() -> Result<()> {
    let config = AppConfig::load()?;

    if config.workspaces.is_empty() {
        println!("No workspaces configured. Run 'bevy-tasks init' to create one.");
        return Ok(());
    }

    for (name, workspace) in &config.workspaces {
        let is_current = config.current_workspace.as_ref() == Some(name);
        let marker = if is_current {
            format!("  {} ", name.bold())
        } else {
            format!("  {} ", name)
        };

        let suffix = if is_current {
            " (current)".green()
        } else {
            "".normal()
        };

        println!("{}: {}{}", marker, workspace.path.display(), suffix);
    }

    Ok(())
}

pub fn switch(name: String) -> Result<()> {
    let mut config = AppConfig::load()?;

    config.switch_workspace(&name)?;
    config.save()?;

    println!("{} Switched to workspace \"{}\"", "✓".green(), name.bold());

    Ok(())
}

pub fn remove(name: String) -> Result<()> {
    let mut config = AppConfig::load()?;

    // Confirmation
    println!(
        "{} This will delete workspace config (files remain on disk)",
        "⚠".yellow()
    );
    print!("Continue? (y/n): ");
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    if input.trim().to_lowercase() != "y" {
        println!("Cancelled.");
        return Ok(());
    }

    config.remove_workspace(&name)?;
    config.save()?;

    println!("{} Removed workspace \"{}\"", "✓".green(), name.bold());

    Ok(())
}

pub fn destroy(name: String) -> Result<()> {
    let mut config = AppConfig::load()?;

    // Get workspace path before removing
    let workspace_path = config.get_workspace(&name)?.path.clone();

    // Confirmation with strong warning
    println!(
        "{} {} This will permanently delete all files in the workspace!",
        "⚠".red().bold(),
        "WARNING:".red().bold()
    );
    println!("  Workspace: {}", name.bold());
    println!("  Location: {}", workspace_path.display());
    println!(
        "\n{} This action cannot be undone!",
        "⚠".red().bold()
    );
    print!("Type the workspace name to confirm: ");
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    if input.trim() != name {
        println!("Cancelled.");
        return Ok(());
    }

    // Delete all files and directories
    if workspace_path.exists() {
        println!("Deleting workspace files...");
        fs::remove_dir_all(&workspace_path)?;
        println!("{} Deleted {}", "✓".green(), workspace_path.display());
    } else {
        println!("{} Workspace directory doesn't exist", "⚠".yellow());
    }

    // Remove from config
    config.remove_workspace(&name)?;
    config.save()?;

    println!(
        "{} Destroyed workspace \"{}\"",
        "✓".green(),
        name.bold()
    );

    Ok(())
}

pub fn retarget(name: String, new_path: PathBuf) -> Result<()> {
    let mut config = AppConfig::load()?;

    config.update_workspace_path(&name, new_path.clone())?;
    config.save()?;

    println!(
        "{} Workspace \"{}\" now points to {}",
        "✓".green(),
        name.bold(),
        new_path.display()
    );

    Ok(())
}

pub fn migrate(name: String, new_path: PathBuf) -> Result<()> {
    let mut config = AppConfig::load()?;

    let old_path = config.get_workspace(&name)?.path.clone();

    // Confirmation
    println!(
        "{} This will move all files from {} to {}",
        "⚠".yellow(),
        old_path.display(),
        new_path.display()
    );
    print!("Continue? (y/n): ");
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    if input.trim().to_lowercase() != "y" {
        println!("Cancelled.");
        return Ok(());
    }

    // Count files for progress
    let mut file_count = 0;
    for entry in fs::read_dir(&old_path)? {
        let entry = entry?;
        file_count += 1;
        println!("  Moving {}...", entry.file_name().to_string_lossy());
    }

    // Create destination directory
    fs::create_dir_all(&new_path)?;

    // Move files
    for entry in fs::read_dir(&old_path)? {
        let entry = entry?;
        let dest = new_path.join(entry.file_name());
        fs::rename(entry.path(), dest)?;
    }

    // Remove old directory
    fs::remove_dir(&old_path)?;

    // Update config
    config.update_workspace_path(&name, new_path.clone())?;
    config.save()?;

    println!(
        "{} Migrated {} files to {}",
        "✓".green(),
        file_count,
        new_path.display()
    );
    println!(
        "{} Workspace \"{}\" now points to {}",
        "✓".green(),
        name.bold(),
        new_path.display()
    );

    Ok(())
}
