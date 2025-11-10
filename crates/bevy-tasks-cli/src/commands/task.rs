use anyhow::{anyhow, Result};
use bevy_tasks_core::Task;
use chrono::{DateTime, NaiveDate, Utc};
use colored::*;
use std::fs;
use std::process::Command;
use uuid::Uuid;

use super::get_current_repo;

pub fn add(
    title: String,
    list_name: Option<String>,
    due: Option<String>,
    workspace: Option<String>,
) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    // Get list ID
    let list_id = if let Some(name) = list_name {
        repo.find_list_by_name(&name)?
    } else {
        // Use first list
        let lists = repo.get_lists()?;
        if lists.is_empty() {
            return Err(anyhow!("No lists found. Create a list first."));
        }
        lists[0].id
    };

    // Create task
    let mut task = Task::new(title.clone());

    // Parse due date if provided
    if let Some(due_str) = due {
        task.due_date = Some(parse_due_date(&due_str)?);
    }

    // Add task
    repo.create_task(list_id, task.clone())?;

    println!(
        "{} Created task \"{}\" ({})",
        "✓".green(),
        title.bold(),
        task.id
    );

    if let Some(due_date) = task.due_date {
        println!("  Due: {}", due_date.format("%Y-%m-%d"));
    }

    Ok(())
}

pub fn complete(task_id_str: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    let task_id = Uuid::parse_str(&task_id_str)?;
    let (list_id, task) = repo.find_task(task_id)?;

    repo.complete_task(list_id, task_id)?;

    println!("{} Completed task \"{}\"", "✓".green(), task.title.bold());

    Ok(())
}

pub fn uncomplete(task_id_str: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    let task_id = Uuid::parse_str(&task_id_str)?;
    let (list_id, task) = repo.find_task(task_id)?;

    repo.uncomplete_task(list_id, task_id)?;

    println!("{} Uncompleted task \"{}\"", "✓".green(), task.title.bold());

    Ok(())
}

pub fn delete(task_id_str: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    let task_id = Uuid::parse_str(&task_id_str)?;
    let (list_id, task) = repo.find_task(task_id)?;

    repo.delete_task(list_id, task_id)?;

    println!("{} Deleted task \"{}\"", "✓".green(), task.title.bold());

    Ok(())
}

pub fn clean(list_name: Option<String>, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    let lists = if let Some(name) = list_name {
        // Clean specific list
        vec![repo.find_list_by_name(&name)?]
    } else {
        // Clean all lists
        repo.get_lists()?.into_iter().map(|l| l.id).collect()
    };

    let mut total_deleted = 0;

    for list_id in lists {
        let list = repo.get_list(list_id)?;
        let completed_tasks: Vec<_> = list
            .tasks
            .into_iter()
            .filter(|t| t.status == bevy_tasks_core::TaskStatus::Completed)
            .collect();

        for task in completed_tasks {
            repo.delete_task(list_id, task.id)?;
            total_deleted += 1;
        }
    }

    println!(
        "{} Deleted {} completed task{}",
        "✓".green(),
        total_deleted,
        if total_deleted == 1 { "" } else { "s" }
    );

    Ok(())
}

pub fn move_task(task_id_str: String, target_list: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    let task_id = Uuid::parse_str(&task_id_str)?;
    let (source_list_id, task) = repo.find_task(task_id)?;
    let target_list_id = repo.find_list_by_name(&target_list)?;

    // Check if already in target list
    if source_list_id == target_list_id {
        return Err(anyhow!("Task is already in list \"{}\"", target_list));
    }

    // Move task: delete from source, create in destination
    repo.delete_task(source_list_id, task_id)?;
    repo.create_task(target_list_id, task)?;

    println!(
        "{} Moved task to list \"{}\"",
        "✓".green(),
        target_list.bold()
    );

    Ok(())
}

pub fn edit(task_id_str: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    let task_id = Uuid::parse_str(&task_id_str)?;
    let (list_id, task) = repo.find_task(task_id)?;

    // Create temporary file with task content
    let temp_file = std::env::temp_dir().join(format!("bevy-task-{}.md", task_id));

    // Write current task content
    let content = format!(
        "# {}\n\nStatus: {:?}\nDue: {}\nCreated: {}\nUpdated: {}\n\n---\n\n{}",
        task.title,
        task.status,
        task.due_date
            .map(|d| d.to_rfc3339())
            .unwrap_or_else(|| "None".to_string()),
        task.created_at.to_rfc3339(),
        task.updated_at.to_rfc3339(),
        task.description
    );

    fs::write(&temp_file, content)?;

    // Get editor from environment or use default
    let editor = std::env::var("EDITOR").unwrap_or_else(|_| "nano".to_string());

    // Open editor
    let status = Command::new(&editor).arg(&temp_file).status()?;

    if !status.success() {
        return Err(anyhow!("Editor exited with error"));
    }

    // Read edited content
    let edited_content = fs::read_to_string(&temp_file)?;

    // Parse edited content (simple parsing for now)
    let mut updated_task = task.clone();
    updated_task.description = edited_content
        .split("---")
        .nth(1)
        .unwrap_or("")
        .trim()
        .to_string();

    // Update task
    repo.update_task(list_id, updated_task)?;

    // Clean up
    fs::remove_file(&temp_file)?;

    println!("{} Updated task \"{}\"", "✓".green(), task.title.bold());

    Ok(())
}

fn parse_due_date(date_str: &str) -> Result<DateTime<Utc>> {
    // Try parsing as full datetime first
    if let Ok(dt) = DateTime::parse_from_rfc3339(date_str) {
        return Ok(dt.with_timezone(&Utc));
    }

    // Try parsing as date only (YYYY-MM-DD)
    if let Ok(naive_date) = NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
        let naive_datetime = naive_date.and_hms_opt(0, 0, 0).unwrap();
        return Ok(DateTime::from_naive_utc_and_offset(naive_datetime, Utc));
    }

    Err(anyhow!(
        "Invalid date format. Use YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS"
    ))
}
