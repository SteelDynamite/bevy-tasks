use anyhow::Result;
use colored::*;

use super::get_current_repo;

pub fn set_group(list_name: String, enabled: bool) -> Result<()> {
    let mut repo = get_current_repo(None)?;

    let list_id = repo.find_list_by_name(&list_name)?;

    repo.set_group_by_due_date(list_id, enabled)?;

    let action = if enabled { "Enabled" } else { "Disabled" };

    println!(
        "{} {} group-by-due-date for list \"{}\"",
        "✓".green(),
        action,
        list_name.bold()
    );

    Ok(())
}
