use anyhow::Result;
use bevy_tasks_core::TaskStatus;
use colored::*;
use std::io::{self, Write};

use super::get_current_repo;

pub fn create(name: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    repo.create_list(name.clone())?;

    println!("{} Created list \"{}\"", "✓".green(), name.bold());

    Ok(())
}

pub fn delete(name: String, force: bool, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    // Find the list
    let list_id = repo.find_list_by_name(&name)?;
    let list = repo.get_list(list_id)?;

    if !force {
        // Show warning and confirmation
        println!(
            "{} {} This will permanently delete the list and all its tasks!",
            "⚠".red().bold(),
            "WARNING:".red().bold()
        );
        println!("  List: {}", name.bold());
        println!("  Tasks: {}", list.tasks.len());
        println!(
            "\n{} This action cannot be undone!",
            "⚠".red().bold()
        );
        print!("Type the list name to confirm: ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;

        if input.trim() != name {
            println!("Cancelled.");
            return Ok(());
        }
    }

    repo.delete_list(list_id)?;

    println!("{} Deleted list \"{}\"", "✓".green(), name.bold());

    Ok(())
}

pub fn rename(old_name: String, new_name: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    // Find the list
    let list_id = repo.find_list_by_name(&old_name)?;

    // Rename it
    repo.rename_list(list_id, new_name.clone())?;

    println!(
        "{} Renamed list \"{}\" to \"{}\"",
        "✓".green(),
        old_name.bold(),
        new_name.bold()
    );

    Ok(())
}

pub fn info(name: String, workspace: Option<String>) -> Result<()> {
    let repo = get_current_repo(workspace)?;

    // Find the list
    let list_id = repo.find_list_by_name(&name)?;
    let list = repo.get_list(list_id)?;

    // Display information
    println!("\n{}", name.bold().underline());
    println!("  ID: {}", list_id);
    println!("  Tasks: {}", list.tasks.len());

    let completed_count = list
        .tasks
        .iter()
        .filter(|t| t.status == TaskStatus::Completed)
        .count();
    let completion_rate = if list.tasks.is_empty() {
        0.0
    } else {
        (completed_count as f64 / list.tasks.len() as f64) * 100.0
    };

    println!("  Completed: {} ({:.1}%)", completed_count, completion_rate);
    println!("  Group by due date: {}", if list.group_by_due_date { "Yes" } else { "No" });
    println!("  Archived: {}", if list.archived { "Yes".yellow() } else { "No".normal() });
    println!("  Created: {}", list.created_at.format("%Y-%m-%d %H:%M:%S"));
    println!("  Updated: {}", list.updated_at.format("%Y-%m-%d %H:%M:%S"));

    Ok(())
}

pub fn reorder(name: String, position: usize, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    // Find the list
    let list_id = repo.find_list_by_name(&name)?;

    // Reorder it
    repo.reorder_list(list_id, position)?;

    println!(
        "{} Moved list \"{}\" to position {}",
        "✓".green(),
        name.bold(),
        position
    );

    Ok(())
}

pub fn archive(name: String, archived: bool, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    // Find the list
    let list_id = repo.find_list_by_name(&name)?;

    // Archive/unarchive it
    repo.archive_list(list_id, archived)?;

    let action = if archived { "Archived" } else { "Unarchived" };
    println!("{} {} list \"{}\"", "✓".green(), action, name.bold());

    Ok(())
}

pub fn merge(
    source: String,
    destination: String,
    delete_source: bool,
    workspace: Option<String>,
) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    // Find both lists
    let source_id = repo.find_list_by_name(&source)?;
    let dest_id = repo.find_list_by_name(&destination)?;

    // Get source tasks
    let source_list = repo.get_list(source_id)?;
    let task_count = source_list.tasks.len();

    // Move all tasks from source to destination
    for task in source_list.tasks {
        // Delete from source
        repo.delete_task(source_id, task.id)?;
        // Create in destination
        repo.create_task(dest_id, task)?;
    }

    println!(
        "{} Moved {} tasks from \"{}\" to \"{}\"",
        "✓".green(),
        task_count,
        source.bold(),
        destination.bold()
    );

    // Delete source list if requested
    if delete_source {
        repo.delete_list(source_id)?;
        println!("{} Deleted source list \"{}\"", "✓".green(), source.bold());
    }

    Ok(())
}

pub fn list_all(
    list_name: Option<String>,
    workspace: Option<String>,
    show_archived: bool,
    show_completed: bool,
) -> Result<()> {
    let repo = get_current_repo(workspace)?;

    let mut lists = repo.get_lists()?;

    // Filter archived lists unless show_archived is true
    if !show_archived {
        lists.retain(|l| !l.archived);
    }

    // Filter tasks based on completion status
    if show_completed {
        // Show only completed tasks
        for list in &mut lists {
            list.tasks.retain(|t| t.status == TaskStatus::Completed);
        }
    } else {
        // Show only uncompleted tasks (default)
        for list in &mut lists {
            list.tasks.retain(|t| t.status != TaskStatus::Completed);
        }
    }

    if lists.is_empty() {
        println!("No task lists found.");
        return Ok(());
    }

    // Filter by list name if provided
    if let Some(ref name) = list_name {
        lists.retain(|l| &l.title == name);
        if lists.is_empty() {
            println!("List \"{}\" not found.", name);
            return Ok(());
        }
    }

    for list in lists {
        let task_count = list.tasks.len();
        let completed_count = list
            .tasks
            .iter()
            .filter(|t| t.status == TaskStatus::Completed)
            .count();

        let archived_label = if list.archived {
            " [archived]".yellow()
        } else {
            "".normal()
        };

        println!(
            "\n{}{} ({} tasks, {} completed)",
            list.title.bold(),
            archived_label,
            task_count,
            completed_count
        );

        for task in &list.tasks {
            let checkbox = if task.status == TaskStatus::Completed {
                "[✓]".green()
            } else {
                "[ ]".normal()
            };

            let due_info = if let Some(due) = task.due_date {
                format!(" (due: {})", due.format("%Y-%m-%d")).yellow()
            } else {
                "".normal()
            };

            let id_display = format!(" ({})", task.id).dimmed();

            println!("  {} {}{}{}", checkbox, task.title, due_info, id_display);
        }
    }

    Ok(())
}
