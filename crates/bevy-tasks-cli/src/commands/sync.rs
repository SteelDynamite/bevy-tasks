use anyhow::{anyhow, Result};
use bevy_tasks_core::{AppConfig, CredentialManager, WebDavClient};
use colored::*;
use std::io::{self, Write};

use super::get_current_repo;

/// Setup WebDAV sync for a workspace
pub async fn setup(workspace_name: Option<String>) -> Result<()> {
    let mut config = AppConfig::load()?;

    // Get workspace
    let (ws_name, _workspace) = if let Some(name) = workspace_name {
        let ws = config.get_workspace(&name)?;
        (name, ws.clone())
    } else {
        let (name, ws) = config.get_current_workspace()?;
        (name.to_string(), ws.clone())
    };

    // Prompt for WebDAV details
    print!("WebDAV URL: ");
    io::stdout().flush()?;
    let mut webdav_url = String::new();
    io::stdin().read_line(&mut webdav_url)?;
    let webdav_url = webdav_url.trim().to_string();

    print!("Username: ");
    io::stdout().flush()?;
    let mut username = String::new();
    io::stdin().read_line(&mut username)?;
    let username = username.trim().to_string();

    print!("Password: ");
    io::stdout().flush()?;
    let password = rpassword::read_password()?;

    // Store credentials in keychain
    let cred_manager = CredentialManager::new();
    cred_manager.store_credentials(&webdav_url, &username, &password)?;

    println!(
        "{} WebDAV credentials saved to system keychain",
        "✓".green()
    );

    // Test connection
    let client = WebDavClient::new(&webdav_url, &username, &password, "")?;
    match client.exists("").await {
        Ok(true) => {
            println!(
                "{} Connection verified for workspace \"{}\"",
                "✓".green(),
                ws_name.bold()
            );
        }
        Ok(false) => {
            println!(
                "{} Connected but base path doesn't exist (will be created on first sync)",
                "⚠".yellow()
            );
        }
        Err(e) => {
            println!(
                "{} Failed to connect to WebDAV server: {}",
                "✗".red(),
                e
            );
            return Err(anyhow!("Connection test failed"));
        }
    }

    // Update workspace config
    config.workspaces.get_mut(&ws_name).map(|ws| {
        ws.webdav_url = Some(webdav_url.clone());
        ws
    });

    config.save()?;

    println!(
        "{} WebDAV sync configured for workspace \"{}\"",
        "✓".green(),
        ws_name.bold()
    );

    Ok(())
}

/// Push local changes to WebDAV server
pub async fn push(workspace_name: Option<String>) -> Result<()> {
    let repo = get_current_repo(workspace_name.clone())?;
    let config = AppConfig::load()?;

    // Get workspace and credentials
    let (ws_name, workspace, username) = get_workspace_and_creds(&config, workspace_name)?;

    let webdav_url = workspace
        .webdav_url
        .as_ref()
        .ok_or_else(|| anyhow!("WebDAV not configured for workspace \"{}\". Run 'bevy-tasks sync --setup' first.", ws_name))?;

    // Get credentials from keychain
    let cred_manager = CredentialManager::new();
    let password = cred_manager.get_credentials_with_username(webdav_url, &username)?;

    // Create WebDAV client
    let client = WebDavClient::new(webdav_url, &username, &password, "")?;

    println!(
        "Syncing workspace \"{}\" to {}...",
        ws_name.bold(),
        webdav_url
    );

    // Perform push
    let result = repo.sync_push(client).await?;

    // Display results
    for file in &result.uploaded {
        println!("  {} Uploading {}", "↑".blue(), file);
    }

    println!(
        "{} Pushed {} files to WebDAV server",
        "✓".green(),
        result.uploaded.len()
    );

    Ok(())
}

/// Pull remote changes from WebDAV server
pub async fn pull(workspace_name: Option<String>) -> Result<()> {
    let repo = get_current_repo(workspace_name.clone())?;
    let config = AppConfig::load()?;

    // Get workspace and credentials
    let (ws_name, workspace, username) = get_workspace_and_creds(&config, workspace_name)?;

    let webdav_url = workspace
        .webdav_url
        .as_ref()
        .ok_or_else(|| anyhow!("WebDAV not configured for workspace \"{}\". Run 'bevy-tasks sync --setup' first.", ws_name))?;

    // Get credentials from keychain
    let cred_manager = CredentialManager::new();
    let password = cred_manager.get_credentials_with_username(webdav_url, &username)?;

    // Create WebDAV client
    let client = WebDavClient::new(webdav_url, &username, &password, "")?;

    println!(
        "Syncing workspace \"{}\" from {}...",
        ws_name.bold(),
        webdav_url
    );

    // Perform pull
    let result = repo.sync_pull(client).await?;

    // Display results
    for file in &result.downloaded {
        println!("  {} Downloading {}", "↓".blue(), file);
    }

    println!(
        "{} Pulled {} files from WebDAV server",
        "✓".green(),
        result.downloaded.len()
    );

    Ok(())
}

/// Perform bidirectional sync
pub async fn sync(workspace_name: Option<String>) -> Result<()> {
    let repo = get_current_repo(workspace_name.clone())?;
    let config = AppConfig::load()?;

    // Get workspace and credentials
    let (ws_name, workspace, username) = get_workspace_and_creds(&config, workspace_name)?;

    let webdav_url = workspace
        .webdav_url
        .as_ref()
        .ok_or_else(|| anyhow!("WebDAV not configured for workspace \"{}\". Run 'bevy-tasks sync --setup' first.", ws_name))?;

    // Get credentials from keychain
    let cred_manager = CredentialManager::new();
    let password = cred_manager.get_credentials_with_username(webdav_url, &username)?;

    // Create WebDAV client
    let client = WebDavClient::new(webdav_url, &username, &password, "")?;

    println!(
        "Syncing workspace \"{}\" with {}...",
        ws_name.bold(),
        webdav_url
    );

    // Perform sync
    let result = repo.sync(client).await?;

    // Display results
    for file in &result.uploaded {
        println!("  {} Uploading {}", "↑".blue(), file);
    }
    for file in &result.downloaded {
        println!("  {} Downloading {}", "↓".blue(), file);
    }

    let total_changes = result.total_changes();
    if total_changes == 0 {
        println!("{} No changes to sync", "✓".green());
    } else {
        println!("{} Sync complete ({} changes)", "✓".green(), total_changes);
    }

    Ok(())
}

/// Show sync status
pub async fn status(workspace_name: Option<String>, all: bool) -> Result<()> {
    let config = AppConfig::load()?;

    if all {
        // Show status for all workspaces
        for (ws_name, workspace) in &config.workspaces {
            println!("Workspace: {}", ws_name.bold());
            if let Some(webdav_url) = &workspace.webdav_url {
                println!("  WebDAV: {}", webdav_url);
                println!("  Status: {}", "Configured".green());
                if let Some(last_sync) = workspace.last_sync {
                    println!("  Last sync: {}", last_sync);
                }
            } else {
                println!("  Status: {}", "Not configured".yellow());
            }
            println!();
        }
    } else {
        // Show status for current/specified workspace
        let (ws_name, workspace) = if let Some(name) = workspace_name {
            let ws = config.get_workspace(&name)?;
            (name, ws.clone())
        } else {
            let (name, ws) = config.get_current_workspace()?;
            (name.to_string(), ws.clone())
        };

        println!("Workspace: {}", ws_name.bold());
        if let Some(webdav_url) = &workspace.webdav_url {
            println!("WebDAV Server: {}", webdav_url);
            println!("Status: {}", "Configured".green());
            if let Some(last_sync) = workspace.last_sync {
                println!("Last sync: {}", last_sync);
            } else {
                println!("Last sync: {}", "Never".yellow());
            }

            // TODO: Show local/remote changes count when file listing works
        } else {
            println!("Status: {}", "Not configured".yellow());
            println!("Run 'bevy-tasks sync --setup' to configure WebDAV sync");
        }
    }

    Ok(())
}

/// Helper to get workspace and credentials
fn get_workspace_and_creds(
    config: &AppConfig,
    workspace_name: Option<String>,
) -> Result<(String, bevy_tasks_core::WorkspaceConfig, String)> {
    let (ws_name, workspace) = if let Some(name) = workspace_name {
        let ws = config.get_workspace(&name)?;
        (name, ws.clone())
    } else {
        let (name, ws) = config.get_current_workspace()?;
        (name.to_string(), ws.clone())
    };

    // For now, hardcode username - in a real implementation, we'd store this in WorkspaceConfig
    // TODO: Store username in WorkspaceConfig
    let username = "user".to_string();

    Ok((ws_name, workspace, username))
}
