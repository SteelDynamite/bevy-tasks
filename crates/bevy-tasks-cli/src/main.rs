mod commands;

use anyhow::Result;
use clap::{Parser, Subcommand};

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
        /// Path to the tasks folder
        path: std::path::PathBuf,
        /// Name of the workspace
        #[arg(short, long)]
        name: String,
    },
    /// Workspace management commands
    #[command(subcommand)]
    Workspace(WorkspaceCommands),
    /// List tasks
    Ls {
        /// List name to show tasks from
        #[arg(short, long)]
        list: Option<String>,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
        /// Show archived lists
        #[arg(long)]
        show_archived: bool,
        /// Show completed tasks (hidden by default)
        #[arg(long)]
        completed: bool,
    },
    /// Manage task lists
    #[command(subcommand)]
    List(ListCommands),
    /// Add a new task
    Add {
        /// Task title
        title: String,
        /// List name to add task to
        #[arg(short, long)]
        list: Option<String>,
        /// Due date (format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
        #[arg(short, long)]
        due: Option<String>,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Complete a task
    Complete {
        /// Task ID
        task_id: String,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Uncomplete a task
    Uncomplete {
        /// Task ID
        task_id: String,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Delete a task
    Delete {
        /// Task ID
        task_id: String,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Clean completed tasks from a list
    Clean {
        /// List name (cleans all lists if not specified)
        #[arg(short, long)]
        list: Option<String>,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Move a task to a different list
    Move {
        /// Task ID
        task_id: String,
        /// Target list name
        list: String,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Edit a task
    Edit {
        /// Task ID
        task_id: String,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
    /// Toggle group-by-due-date for a list
    Group {
        #[command(subcommand)]
        command: GroupCommands,
    },
    /// WebDAV sync operations
    Sync {
        #[command(subcommand)]
        command: Option<SyncCommands>,
        /// Workspace name
        #[arg(short, long)]
        workspace: Option<String>,
    },
}

#[derive(Subcommand)]
enum WorkspaceCommands {
    /// Add a new workspace
    Add {
        /// Workspace name
        name: String,
        /// Path to the tasks folder
        path: std::path::PathBuf,
    },
    /// List all workspaces
    List,
    /// Switch to a different workspace
    Switch {
        /// Workspace name
        name: String,
    },
    /// Remove a workspace (keeps files on disk)
    Remove {
        /// Workspace name
        name: String,
    },
    /// Destroy a workspace (deletes all files and config)
    Destroy {
        /// Workspace name
        name: String,
    },
    /// Update workspace path (files already at new location)
    Retarget {
        /// Workspace name
        name: String,
        /// New path
        path: std::path::PathBuf,
    },
    /// Migrate workspace files to a new location
    Migrate {
        /// Workspace name
        name: String,
        /// New path
        path: std::path::PathBuf,
    },
}

#[derive(Subcommand)]
enum ListCommands {
    /// Create a new task list
    Create {
        /// List name
        name: String,
    },
    /// Delete a task list
    Delete {
        /// List name
        name: String,
        /// Delete files without confirmation
        #[arg(short, long)]
        force: bool,
    },
    /// Rename a task list
    Rename {
        /// Current list name
        old_name: String,
        /// New list name
        new_name: String,
    },
    /// Show detailed information about a list
    Info {
        /// List name
        name: String,
    },
    /// Reorder a list's position
    Reorder {
        /// List name
        name: String,
        /// New position (0-based index)
        position: usize,
    },
    /// Archive a list (hide from default view)
    Archive {
        /// List name
        name: String,
    },
    /// Unarchive a list
    Unarchive {
        /// List name
        name: String,
    },
    /// Merge one list into another
    Merge {
        /// Source list name
        source: String,
        /// Destination list name
        destination: String,
        /// Delete source list after merging
        #[arg(short, long)]
        delete_source: bool,
    },
}

#[derive(Subcommand)]
enum GroupCommands {
    /// Enable group-by-due-date for a list
    Enable {
        /// List name
        #[arg(short, long)]
        list: String,
    },
    /// Disable group-by-due-date for a list
    Disable {
        /// List name
        #[arg(short, long)]
        list: String,
    },
}

#[derive(Subcommand)]
enum SyncCommands {
    /// Configure WebDAV sync for a workspace
    Setup,
    /// Push local changes to WebDAV server
    Push,
    /// Pull remote changes from WebDAV server
    Pull,
    /// Show sync status
    Status {
        /// Show status for all workspaces
        #[arg(long)]
        all: bool,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init { path, name } => commands::init::execute(path, name),
        Commands::Workspace(cmd) => match cmd {
            WorkspaceCommands::Add { name, path } => commands::workspace::add(name, path),
            WorkspaceCommands::List => commands::workspace::list(),
            WorkspaceCommands::Switch { name } => commands::workspace::switch(name),
            WorkspaceCommands::Remove { name } => commands::workspace::remove(name),
            WorkspaceCommands::Destroy { name } => commands::workspace::destroy(name),
            WorkspaceCommands::Retarget { name, path } => {
                commands::workspace::retarget(name, path)
            }
            WorkspaceCommands::Migrate { name, path } => commands::workspace::migrate(name, path),
        },
        Commands::Ls {
            list,
            workspace,
            show_archived,
            completed,
        } => commands::list::list_all(list, workspace, show_archived, completed),
        Commands::List(cmd) => match cmd {
            ListCommands::Create { name } => commands::list::create(name, None),
            ListCommands::Delete { name, force } => commands::list::delete(name, force, None),
            ListCommands::Rename { old_name, new_name } => {
                commands::list::rename(old_name, new_name, None)
            }
            ListCommands::Info { name } => commands::list::info(name, None),
            ListCommands::Reorder { name, position } => {
                commands::list::reorder(name, position, None)
            }
            ListCommands::Archive { name } => commands::list::archive(name, true, None),
            ListCommands::Unarchive { name } => commands::list::archive(name, false, None),
            ListCommands::Merge {
                source,
                destination,
                delete_source,
            } => commands::list::merge(source, destination, delete_source, None),
        },
        Commands::Add {
            title,
            list,
            due,
            workspace,
        } => commands::task::add(title, list, due, workspace),
        Commands::Complete { task_id, workspace } => commands::task::complete(task_id, workspace),
        Commands::Uncomplete { task_id, workspace } => commands::task::uncomplete(task_id, workspace),
        Commands::Delete { task_id, workspace } => commands::task::delete(task_id, workspace),
        Commands::Clean { list, workspace } => commands::task::clean(list, workspace),
        Commands::Move {
            task_id,
            list,
            workspace,
        } => commands::task::move_task(task_id, list, workspace),
        Commands::Edit { task_id, workspace } => commands::task::edit(task_id, workspace),
        Commands::Group { command } => match command {
            GroupCommands::Enable { list } => commands::group::set_group(list, true),
            GroupCommands::Disable { list } => commands::group::set_group(list, false),
        },
        Commands::Sync { command, workspace } => match command {
            Some(SyncCommands::Setup) => commands::sync::setup(workspace).await,
            Some(SyncCommands::Push) => commands::sync::push(workspace).await,
            Some(SyncCommands::Pull) => commands::sync::pull(workspace).await,
            Some(SyncCommands::Status { all }) => commands::sync::status(workspace, all).await,
            None => commands::sync::sync(workspace).await,
        },
    }
}
