use anyhow::Result;
use bevy_tasks_core::TaskStatus;
use colored::*;

use super::get_current_repo;

pub fn create(name: String, workspace: Option<String>) -> Result<()> {
    let mut repo = get_current_repo(workspace)?;

    repo.create_list(name.clone())?;

    println!("{} Created list \"{}\"", "✓".green(), name.bold());

    Ok(())
}

pub fn list_all(workspace: Option<String>) -> Result<()> {
    let repo = get_current_repo(workspace)?;

    let lists = repo.get_lists()?;

    if lists.is_empty() {
        println!("No task lists found.");
        return Ok(());
    }

    for list in lists {
        let task_count = list.tasks.len();
        let completed_count = list
            .tasks
            .iter()
            .filter(|t| t.status == TaskStatus::Completed)
            .count();

        println!(
            "\n{} ({} tasks, {} completed)",
            list.title.bold(),
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

            println!("  {} {}{}", checkbox, task.title, due_info);
        }
    }

    Ok(())
}
