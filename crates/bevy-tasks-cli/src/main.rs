mod commands;
mod output;

use anyhow::Result;
use clap::{Parser, Subcommand};
use commands::*;

#[derive(Parser)]
#[command(name = "bevy-tasks")]
#[command(about = "A local-first, cross-platform tasks application", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize a new workspace
    Init {
        /// Path to store tasks
        path: String,
        /// Name of the workspace
        #[arg(short, long)]
        name: String,
    },

    /// Manage workspaces
    #[command(subcommand)]
    Workspace(WorkspaceCommands),

    /// Manage task lists
    #[command(subcommand)]
    List(ListCommands),

    /// Add a new task
    Add {
        /// Task title
        title: String,
        /// List to add task to
        #[arg(short, long)]
        list: Option<String>,
        /// Due date (ISO 8601 format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
        #[arg(short, long)]
        due: Option<String>,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Mark a task as complete
    Complete {
        /// Task ID
        task_id: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Delete a task
    Delete {
        /// Task ID
        task_id: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Edit a task
    Edit {
        /// Task ID
        task_id: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Toggle group-by-due-date for a list
    #[command(subcommand)]
    Group(GroupCommands),
}

#[derive(Subcommand)]
enum WorkspaceCommands {
    /// Add a new workspace
    Add {
        /// Name of the workspace
        name: String,
        /// Path to store tasks
        path: String,
    },

    /// List all workspaces
    List,

    /// Switch to a different workspace
    Switch {
        /// Name of the workspace
        name: String,
    },

    /// Remove a workspace
    Remove {
        /// Name of the workspace
        name: String,
    },

    /// Update workspace path without moving files
    Retarget {
        /// Name of the workspace
        name: String,
        /// New path
        path: String,
    },

    /// Move workspace files to a new location
    Migrate {
        /// Name of the workspace
        name: String,
        /// New path
        path: String,
    },
}

#[derive(Subcommand)]
enum ListCommands {
    /// Create a new task list
    Create {
        /// Name of the list
        name: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Show all tasks (or tasks in a specific list)
    Show {
        /// Name of the list to show
        #[arg(short, long)]
        list: Option<String>,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Delete a task list
    Delete {
        /// Name of the list to delete
        name: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },
}

#[derive(Subcommand)]
enum GroupCommands {
    /// Enable group-by-due-date for a list
    Enable {
        /// Name of the list
        #[arg(short, long)]
        list: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },

    /// Disable group-by-due-date for a list
    Disable {
        /// Name of the list
        #[arg(short, long)]
        list: String,
        /// Workspace to use
        #[arg(short, long)]
        workspace: Option<String>,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init { path, name } => {
            init::execute(path, name)?;
        }
        Commands::Workspace(cmd) => match cmd {
            WorkspaceCommands::Add { name, path } => {
                workspace::add(name, path)?;
            }
            WorkspaceCommands::List => {
                workspace::list()?;
            }
            WorkspaceCommands::Switch { name } => {
                workspace::switch(name)?;
            }
            WorkspaceCommands::Remove { name } => {
                workspace::remove(name)?;
            }
            WorkspaceCommands::Retarget { name, path } => {
                workspace::retarget(name, path)?;
            }
            WorkspaceCommands::Migrate { name, path } => {
                workspace::migrate(name, path)?;
            }
        },
        Commands::List(cmd) => match cmd {
            ListCommands::Create { name, workspace } => {
                list::create(name, workspace)?;
            }
            ListCommands::Show { list, workspace } => {
                list::show(list, workspace)?;
            }
            ListCommands::Delete { name, workspace } => {
                list::delete(name, workspace)?;
            }
        },
        Commands::Add { title, list, due, workspace } => {
            task::add(title, list, due, workspace)?;
        }
        Commands::Complete { task_id, workspace } => {
            task::complete(task_id, workspace)?;
        }
        Commands::Delete { task_id, workspace } => {
            task::delete(task_id, workspace)?;
        }
        Commands::Edit { task_id, workspace } => {
            task::edit(task_id, workspace)?;
        }
        Commands::Group(cmd) => match cmd {
            GroupCommands::Enable { list, workspace } => {
                group::enable(list, workspace)?;
            }
            GroupCommands::Disable { list, workspace } => {
                group::disable(list, workspace)?;
            }
        },
    }

    Ok(())
}
