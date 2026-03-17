use anyhow::{Context, Result};
use colored::*;
use crate::output;
use crate::commands::get_repository;

pub fn create(name: String, workspace: Option<String>) -> Result<()> {
    let (mut repo, _workspace_name) = get_repository(workspace)?;

    repo.create_list(name.clone())
        .context("Failed to create list")?;

    output::success(&format!("Created list \"{}\"", name));

    Ok(())
}

pub fn show(list_name: Option<String>, workspace: Option<String>) -> Result<()> {
    let (repo, _workspace_name) = get_repository(workspace)?;

    let lists = repo.get_lists()
        .context("Failed to get lists")?;

    if lists.is_empty() {
        println!("No lists found. Create one with 'bevy-tasks list create <name>'");
        return Ok(());
    }

    // If a specific list is requested, show only that one
    if let Some(name) = list_name {
        let list = lists.iter()
            .find(|l| l.title == name)
            .ok_or_else(|| anyhow::anyhow!("List '{}' not found", name))?;

        println!("{} {} {}", list.title.bold(), format!("({} tasks)", list.tasks.len()).dimmed(), "");

        if list.tasks.is_empty() {
            println!("  No tasks");
        } else {
            for task in &list.tasks {
                let checkbox = if task.status == bevy_tasks_core::TaskStatus::Completed {
                    "[✓]".green()
                } else {
                    "[ ]".normal()
                };

                let due_str = if let Some(due) = task.due_date {
                    format!(" (due: {})", due.format("%Y-%m-%d")).yellow().to_string()
                } else {
                    String::new()
                };

                let id_str = task.id.to_string();
                println!("  {} {}{} {}", checkbox, task.title, due_str, id_str.dimmed());
            }
        }
    } else {
        // Show all lists
        for list in &lists {
            println!("{} {}", list.title.bold(), format!("({} tasks)", list.tasks.len()).dimmed());

            if list.tasks.is_empty() {
                println!("  No tasks");
            } else {
                for task in &list.tasks {
                    let checkbox = if task.status == bevy_tasks_core::TaskStatus::Completed {
                        "[✓]".green()
                    } else {
                        "[ ]".normal()
                    };

                    let due_str = if let Some(due) = task.due_date {
                        format!(" (due: {})", due.format("%Y-%m-%d")).yellow().to_string()
                    } else {
                        String::new()
                    };

                    let id_str = task.id.to_string();
                    println!("  {} {}{} {}", checkbox, task.title, due_str, id_str.dimmed());
                }
            }
            println!();
        }
    }

    Ok(())
}

pub fn delete(name: String, workspace: Option<String>) -> Result<()> {
    let (mut repo, _workspace_name) = get_repository(workspace)?;

    let lists = repo.get_lists()
        .context("Failed to get lists")?;

    let list = lists.iter()
        .find(|l| l.title == name)
        .ok_or_else(|| anyhow::anyhow!("List '{}' not found", name))?;

    // Confirm
    output::warning(&format!("This will delete list \"{}\" and all its tasks", name));
    print!("Continue? (y/n): ");
    use std::io::{self, Write};
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    if input.trim().to_lowercase() != "y" {
        println!("Cancelled");
        return Ok(());
    }

    repo.delete_list(list.id)
        .context("Failed to delete list")?;

    output::success(&format!("Deleted list \"{}\"", name));

    Ok(())
}
