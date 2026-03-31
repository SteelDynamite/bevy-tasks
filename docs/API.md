# Onyx Core - API Documentation

## Overview

The `onyx-core` library provides a complete backend for managing tasks in a local-first manner. Tasks are stored as markdown files with YAML frontmatter, compatible with Obsidian and other markdown editors.

## Core Concepts

### Data Models

#### Task

Represents an individual task.

```rust
pub struct Task {
    pub id: Uuid,
    pub title: String,
    pub description: String,
    pub status: TaskStatus,
    pub due_date: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub parent_id: Option<Uuid>,
}

pub enum TaskStatus {
    Backlog,     // Not yet completed
    Completed,   // Done
}
```

**Creating a Task:**

```rust
use onyx_core::Task;

// Simple task
let task = Task::new("Buy groceries".to_string());

// Task with description and due date
let task = Task::new("Review PR #123".to_string())
    .with_description("Check the authentication changes".to_string())
    .with_due_date(chrono::Utc::now() + chrono::Duration::days(2));
```

#### TaskList

Represents a collection of tasks.

```rust
pub struct TaskList {
    pub id: Uuid,
    pub title: String,
    pub tasks: Vec<Task>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub group_by_due_date: bool,
}
```

### Configuration

#### AppConfig

Global application configuration supporting multiple workspaces.

```rust
pub struct AppConfig {
    pub workspaces: HashMap<String, WorkspaceConfig>,
    pub current_workspace: Option<String>,
}
```

**Location:**
- Windows: `%APPDATA%/onyx/config.json`
- Linux: `~/.config/onyx/config.json`
- macOS: `~/Library/Application Support/onyx/config.json`

**Usage:**

```rust
use onyx_core::AppConfig;

// Load config
let config_path = AppConfig::get_config_path();
let mut config = AppConfig::load_from_file(&config_path)?;

// Add workspace
config.add_workspace(
    "personal".to_string(),
    WorkspaceConfig::new(PathBuf::from("/home/user/tasks"))
);

// Set current workspace
config.set_current_workspace("personal".to_string())?;

// Save config
config.save_to_file(&config_path)?;
```

#### WorkspaceConfig

Configuration for a single workspace.

```rust
pub struct WorkspaceConfig {
    pub path: PathBuf,
}
```

## TaskRepository API

The main interface for interacting with tasks and lists.

### Initialization

```rust
use onyx_core::TaskRepository;
use std::path::PathBuf;

// Open existing repository
let repo = TaskRepository::new(PathBuf::from("/path/to/tasks"))?;

// Initialize new repository
let repo = TaskRepository::init(PathBuf::from("/path/to/tasks"))?;
```

### Task Operations

#### Create Task

```rust
let task = Task::new("My task".to_string());
let created_task = repo.create_task(list_id, task)?;
```

#### Get Task

```rust
let task = repo.get_task(list_id, task_id)?;
```

#### Update Task

```rust
let mut task = repo.get_task(list_id, task_id)?;
task.title = "Updated title".to_string();
task.complete();
repo.update_task(list_id, task)?;
```

#### Delete Task

```rust
repo.delete_task(list_id, task_id)?;
```

#### List Tasks

```rust
let tasks = repo.list_tasks(list_id)?;
```

### List Operations

#### Create List

```rust
let list = repo.create_list("My List".to_string())?;
```

#### Get Lists

```rust
let lists = repo.get_lists()?;
```

#### Get Specific List

```rust
let list = repo.get_list(list_id)?;
```

#### Delete List

```rust
repo.delete_list(list_id)?;
```

### Task Ordering

#### Reorder Task

```rust
// Move task to position 0 (first)
repo.reorder_task(list_id, task_id, 0)?;
```

#### Get Task Order

```rust
let order = repo.get_task_order(list_id)?;
// Returns: Vec<Uuid> - ordered list of task IDs
```

### Grouping

#### Enable/Disable Group by Due Date

```rust
// Enable grouping
repo.set_group_by_due_date(list_id, true)?;

// Disable grouping
repo.set_group_by_due_date(list_id, false)?;

// Check current setting
let is_grouped = repo.get_group_by_due_date(list_id)?;
```

## File Format

### Task Files

Tasks are stored as `.md` files with YAML frontmatter:

```markdown
---
id: 550e8400-e29b-41d4-a716-446655440000
status: backlog
due: 2026-11-15T14:00:00Z
created: 2026-10-26T10:00:00Z
updated: 2026-10-26T12:30:00Z
parent: 550e8400-e29b-41d4-a716-446655440001
---

Task description and notes go here in **markdown** format.

- Can include lists
- Rich formatting
- Links, etc.
```

The filename (without `.md`) becomes the task title.

### List Metadata

Each list folder contains a `.listdata.json` file:

```json
{
  "id": "list-uuid-1",
  "created_at": "2026-10-26T10:00:00Z",
  "updated_at": "2026-10-27T14:30:00Z",
  "group_by_due_date": false,
  "task_order": [
    "task-uuid-1",
    "task-uuid-2",
    "task-uuid-3"
  ]
}
```

### Root Metadata

The root folder contains a `.metadata.json` file:

```json
{
  "version": 1,
  "list_order": ["list-uuid-1", "list-uuid-2"],
  "last_opened_list": "list-uuid-1"
}
```

## WebDAV & Sync

The sync module provides bi-directional WebDAV synchronization with three-way diff, offline queuing, and platform keychain credential storage.

### Sync Functions

Sync functions live in the `onyx_core::sync` module as standalone functions (not on `TaskRepository`).

#### Sync a Workspace

```rust
use onyx_core::sync::{sync_workspace, SyncMode};
use std::path::Path;

// Full bi-directional sync
let result = sync_workspace(
    Path::new("/home/user/tasks"),
    "https://nextcloud.example.com/remote.php/dav/files/user/Tasks",
    "username",
    "password",
    SyncMode::Full,
).await?;

// Push-only or pull-only
sync_workspace(path, url, user, pass, SyncMode::PushOnly).await?;
sync_workspace(path, url, user, pass, SyncMode::PullOnly).await?;
```

#### Check Sync Status

```rust
use onyx_core::sync::get_sync_status;

let status = get_sync_status(Path::new("/home/user/tasks"))?;
// Returns SyncStatusInfo with last sync time, pending changes, etc.
```

### Credential Storage

Credentials are stored in the platform keychain (Windows Credential Manager, macOS Keychain, Linux Secret Service).

```rust
use onyx_core::webdav::{store_credentials, load_credentials, delete_credentials};

// Store credentials
store_credentials("nextcloud.example.com", "username", "password")?;

// Load credentials
let (username, password) = load_credentials("nextcloud.example.com")?;

// Delete credentials
delete_credentials("nextcloud.example.com")?;
```

### WebDAV Client

```rust
use onyx_core::webdav::WebDavClient;

let client = WebDavClient::new(
    "https://nextcloud.example.com/remote.php/dav/files/user/Tasks",
    "username",
    "password",
);

// Test connection
client.test_connection().await?;

// List remote files
let files = client.list_files("/").await?;

// Upload/download
client.put_file("My Tasks/task.md", content).await?;
let data = client.get_file("My Tasks/task.md").await?;

// Directory operations
client.ensure_dir("My Tasks").await?;
client.delete_file("old-task.md").await?;
```

### Sync Strategy

- **Three-way diff**: Compares local state, remote state, and last-known baseline to determine actions (upload, download, delete local/remote)
- **Conflict resolution**: Last-write-wins using file timestamps
- **Offline queue**: Pending operations are queued and replayed when connectivity returns
- **Sync state**: Stored in `.syncstate.json` within the workspace directory

## Error Handling

All operations return `Result<T, Error>` where `Error` is:

```rust
pub enum Error {
    Io(io::Error),
    Serialization(String),
    NotFound(String),
    InvalidData(String),
    WorkspaceNotFound(String),
    ListNotFound(String),
    TaskNotFound(String),
}
```

## Example: Complete Workflow

```rust
use onyx_core::{TaskRepository, Task, AppConfig, WorkspaceConfig};
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize repository
    let path = PathBuf::from("/home/user/tasks");
    let mut repo = TaskRepository::init(path.clone())?;

    // Create a list
    let list = repo.create_list("My Tasks".to_string())?;

    // Create tasks
    let task1 = Task::new("Buy groceries".to_string());
    let task1 = repo.create_task(list.id, task1)?;

    let task2 = Task::new("Call dentist".to_string())
        .with_due_date(chrono::Utc::now() + chrono::Duration::days(1));
    let task2 = repo.create_task(list.id, task2)?;

    // List all tasks
    let tasks = repo.list_tasks(list.id)?;
    for task in tasks {
        println!("- [{}] {}",
            if task.status == TaskStatus::Completed { "✓" } else { " " },
            task.title
        );
    }

    // Complete a task
    let mut task = repo.get_task(list.id, task1.id)?;
    task.complete();
    repo.update_task(list.id, task)?;

    // Configure workspace
    let mut config = AppConfig::new();
    config.add_workspace("personal".to_string(), WorkspaceConfig::new(path));
    config.set_current_workspace("personal".to_string())?;
    config.save_to_file(&AppConfig::get_config_path())?;

    Ok(())
}
```

## Testing

The core library includes comprehensive tests. Run them with:

```bash
cargo test -p onyx-core
```

Key test areas:
- Task CRUD operations
- List management
- Task ordering
- Markdown parsing
- Metadata persistence
- Error handling

## Thread Safety

**Note:** The current implementation is not thread-safe. If you need concurrent access:

1. Use external synchronization (e.g., `Mutex<TaskRepository>`)
2. Create separate repository instances per thread (file system will handle locking)
3. Consider implementing a service layer with proper locking

Future versions may include built-in concurrency support.
