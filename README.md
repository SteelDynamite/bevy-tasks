# Bevy Tasks

A local-first, cross-platform tasks application inspired by Google Tasks. Built with Rust for high performance and true native support across Windows, Linux, macOS, iOS, and Android.

## Core Principles

- **Local-First**: Your data, your folder, your control
- **Fast**: Sub-second startup, instant response
- **Cross-Platform**: Single codebase, all platforms
- **Flexible**: Multiple workspaces for different contexts (personal, shared, work, etc.)

## Features

### Phase 1 ✅ Complete - Core Library & CLI MVP

- ✅ Full-featured task management backend
- ✅ Multiple workspace support with full lifecycle management
  - Create, switch, remove, destroy, retarget, migrate
- ✅ Markdown-based task storage with YAML frontmatter (Obsidian-compatible)
- ✅ Advanced list management
  - Create, delete, rename, archive, reorder, merge lists
  - List info with statistics
  - Archived lists filtering
- ✅ Task operations
  - Create, complete, delete, edit, move between lists
  - Manual task ordering
  - Due date support
  - Task grouping by due date
- ✅ Command-line interface (CLI)
  - Intuitive `ls` command for viewing tasks
  - Comprehensive `list` subcommands for list management
  - Per-command workspace targeting with `--workspace` flag
- ✅ Comprehensive test coverage (30 tests passing)

### Phase 2 ✅ 87.5% Complete - WebDAV Sync

- ✅ WebDAV client integration (using `reqwest_dav` library)
- ✅ Secure credential storage (system keychain)
- ✅ Push/pull/bidirectional sync operations
- ✅ Conflict resolution (last-write-wins strategy)
- ✅ CLI sync commands (`setup`, `push`, `pull`, `status`)
- ✅ Per-workspace WebDAV configuration
- ⏳ End-to-end testing with Nextcloud/ownCloud (pending)

### Coming Soon

- **Phase 3**: Desktop GUI with egui
- **Phase 4**: iOS and Android support
- **Phase 5**: Advanced GUI features
- **Phase 6**: Mobile platform-specific features
- **Phase 7**: Advanced features, imports, and collaboration

## Installation

### Prerequisites

- **Rust**: 1.70 or later
- **System libraries** (for Linux):
  - OpenSSL development libraries: `sudo apt install libssl-dev pkg-config` (Ubuntu/Debian) or `sudo dnf install openssl-devel` (Fedora)
  - For keychain support: `libsecret` (usually pre-installed)

### From Source

```bash
# Clone the repository
git clone <repository-url>
cd bevy-tasks

# Build the CLI
cargo build --release -p bevy-tasks-cli

# The binary will be at: target/release/bevy-tasks

# Optionally, install it to your PATH
cargo install --path crates/bevy-tasks-cli
```

## Quick Start

### Initialize Your First Workspace

```bash
# Create a new workspace named "personal" at ~/Documents/Tasks
bevy-tasks init ~/Documents/Tasks --name personal
```

This will:
- Create the tasks folder at the specified location
- Initialize the workspace with proper metadata
- Create a default list called "My Tasks"
- Set it as your current workspace

### Add Tasks

```bash
# Add a simple task
bevy-tasks add "Buy groceries"

# Add a task to a specific list
bevy-tasks add "Review PR #123" --list Work

# Add a task with a due date
bevy-tasks add "Team meeting" --due 2025-11-15
```

### View Tasks

```bash
# List all uncompleted tasks (default behavior)
bevy-tasks ls

# View tasks in a specific list
bevy-tasks ls --list Work

# Show only completed tasks
bevy-tasks ls --completed
```

Task IDs are displayed in dimmed gray at the end of each task for easy reference.

**Note**: By default, `ls` shows only uncompleted tasks. Use `--completed` to view only completed tasks.

### Complete and Delete Tasks

```bash
# Complete a task (use the task ID from ls output)
bevy-tasks complete <task-id>

# Uncomplete a task
bevy-tasks uncomplete <task-id>

# Delete a task
bevy-tasks delete <task-id>

# Move a task to a different list
bevy-tasks move <task-id> "Target List"

# Clean (delete) all completed tasks
bevy-tasks clean

# Clean completed tasks from a specific list
bevy-tasks clean --list "My Tasks"
```

### Edit Tasks

```bash
# Edit a task in your default editor
bevy-tasks edit <task-id>
```

The edit command will open the task in your `$EDITOR` (or `nano` by default).

## CLI Usage

### Workspace Management

```bash
# Add a new workspace
bevy-tasks workspace add shared ~/Dropbox/TeamTasks

# List all workspaces
bevy-tasks workspace list

# Switch to a different workspace
bevy-tasks workspace switch shared

# Retarget a workspace (files already at new location)
bevy-tasks workspace retarget personal ~/new/path/to/Tasks

# Migrate workspace files to a new location
bevy-tasks workspace migrate personal ~/Dropbox/Tasks

# Remove a workspace (keeps files on disk)
bevy-tasks workspace remove shared

# Destroy a workspace (deletes all files and config)
bevy-tasks workspace destroy shared
```

### List Management

```bash
# Create a new task list
bevy-tasks list create "Work"

# View all tasks
bevy-tasks ls

# View tasks in a specific list
bevy-tasks ls --list Work

# Show detailed information about a list
bevy-tasks list info "Work"

# Rename a list
bevy-tasks list rename "Old Name" "New Name"

# Delete a list (with confirmation)
bevy-tasks list delete "Work"

# Delete a list without confirmation
bevy-tasks list delete "Work" --force

# Merge one list into another
bevy-tasks list merge "Source" "Destination"

# Merge and delete source list
bevy-tasks list merge "Source" "Destination" --delete-source

# Archive a list (hide from default view)
bevy-tasks list archive "Work"

# Unarchive a list
bevy-tasks list unarchive "Work"

# Show archived lists
bevy-tasks ls --show-archived

# Reorder a list (change display position)
bevy-tasks list reorder "Work" 0

# Enable grouping by due date
bevy-tasks group enable --list Work

# Disable grouping by due date
bevy-tasks group disable --list Work
```

### Using Specific Workspaces

Most commands support a `--workspace` flag to operate on a specific workspace without switching:

```bash
# Add a task to a specific workspace
bevy-tasks add "Team standup" --workspace shared

# Complete a task in a specific workspace
bevy-tasks complete <task-id> --workspace shared

# View tasks from a specific workspace
bevy-tasks ls --workspace shared
```

### WebDAV Sync (Phase 2)

Synchronize your tasks across devices using WebDAV (compatible with Nextcloud, ownCloud, and other WebDAV servers).

#### Setup WebDAV Sync

```bash
# Configure WebDAV for the current workspace
bevy-tasks sync --setup

# You'll be prompted for:
# - WebDAV URL (e.g., https://nextcloud.example.com/remote.php/dav/files/user/Tasks)
# - Username
# - Password (securely stored in system keychain)

# Configure WebDAV for a specific workspace
bevy-tasks sync --setup --workspace shared
```

#### Sync Operations

```bash
# Push local changes to the server
bevy-tasks sync --push

# Pull remote changes from the server
bevy-tasks sync --pull

# Perform bidirectional sync (pull + push)
bevy-tasks sync

# Check sync status
bevy-tasks sync --status

# Check status for all workspaces
bevy-tasks sync --status --all
```

#### How Sync Works

- **Credentials**: Stored securely in your system keychain (Credential Manager on Windows, Keychain on macOS, Secret Service on Linux)
- **Conflict Resolution**: Last-write-wins strategy based on file timestamps
- **File Format**: Same markdown files with YAML frontmatter - works seamlessly with Obsidian
- **Workspace Isolation**: Each workspace can have its own WebDAV configuration

## Data Format

Tasks are stored as individual markdown files with YAML frontmatter:

```markdown
---
id: 550e8400-e29b-41d4-a716-446655440000
status: backlog
due: 2025-11-15T14:00:00Z
created: 2025-10-26T10:00:00Z
updated: 2025-10-26T12:30:00Z
---

Task description and notes go here in **markdown** format.

- Can include lists
- Rich formatting
- Links, etc.
```

### File System Structure

```
~/Documents/Tasks/           # User-selected folder
├── .metadata.json           # Global: list ordering, last opened list
├── My Tasks/                # Task list folder
│   ├── .listdata.json       # List metadata: task order, id, timestamps
│   ├── Buy groceries.md     # Task file
│   └── Call dentist.md      # Task file
└── Work/                    # Another task list
    ├── .listdata.json
    ├── Review PRs.md
    └── Team meeting prep.md
```

## Configuration

### Application Config

Application configuration is stored in platform-specific locations:

- **Windows**: `%APPDATA%\bevy-tasks\config.json`
- **Linux**: `~/.config/bevy-tasks/config.json`
- **macOS**: `~/Library/Application Support/bevy-tasks/config.json`

The configuration file contains:
- Workspace definitions (name, path, WebDAV URL)
- Current workspace selection
- Last sync timestamps

### WebDAV Credentials

WebDAV credentials are stored securely in your system's credential storage:

- **Windows**: Credential Manager
- **macOS**: Keychain
- **Linux**: Secret Service (via libsecret)

Credentials are stored per WebDAV server domain, identified by the key format: `com.bevy-tasks.webdav.{domain}`

## Architecture

Bevy Tasks uses a clean separation between backend and frontend:

- **bevy-tasks-core**: Core library with data models, storage, sync, and repository pattern
  - `models.rs` - Task and TaskList data structures
  - `storage.rs` - File system operations and markdown I/O
  - `repository.rs` - High-level task management API
  - `config.rs` - Workspace and app configuration
  - `credentials.rs` - Secure keychain integration (Phase 2)
  - `webdav.rs` - WebDAV client wrapper using `reqwest_dav` (Phase 2)
  - `sync.rs` - Sync engine and conflict resolution (Phase 2)
- **bevy-tasks-cli**: Command-line interface with async support
- **bevy-tasks-gui**: Graphical user interface (coming in Phase 3)

### Technology Stack

**Phase 1 & 2:**
- **Storage**: File system with markdown + YAML frontmatter
- **WebDAV**: `reqwest_dav` 0.2 for WebDAV protocol
- **Credentials**: `keyring` 3.0 for cross-platform keychain access
- **CLI**: `clap` for argument parsing, `tokio` for async runtime
- **Testing**: Comprehensive unit and integration tests

### Cargo Workspace Structure

```
bevy-tasks/
├── Cargo.toml                    # Workspace definition
├── PLAN.md                       # Development plan
├── README.md
├── crates/
│   ├── bevy-tasks-core/          # Core library (backend)
│   ├── bevy-tasks-cli/           # CLI frontend
│   └── bevy-tasks-gui/           # GUI frontend (Phase 3+)
└── docs/
```

## Development

### Running Tests

```bash
# Test the core library
cargo test -p bevy-tasks-core

# Test all crates
cargo test

# Run tests with output
cargo test -- --nocapture

# Run specific test
cargo test -p bevy-tasks-core sync::tests
```

**Current Test Coverage:**
- 24 unit and integration tests passing
- Core library: models, storage, repository, config, credentials, webdav, sync
- Test coverage: >80%

### Building

```bash
# Build everything
cargo build

# Build just the CLI
cargo build -p bevy-tasks-cli

# Build in release mode
cargo build --release
```

### Running from Source

```bash
# Run the CLI directly
cargo run -p bevy-tasks-cli -- init ~/test-tasks --name test
cargo run -p bevy-tasks-cli -- add "Test task"
cargo run -p bevy-tasks-cli -- ls

# Test sync commands (requires WebDAV server)
cargo run -p bevy-tasks-cli -- sync --setup
cargo run -p bevy-tasks-cli -- sync --status
```

### Project Stats

- **Lines of Code**: ~3,500+ (Phase 1 & 2)
- **Modules**: 10 core modules + CLI commands
- **Dependencies**: Minimal, focused on quality libraries
- **Tests**: 24 comprehensive tests
- **Build Time**: ~3-5 seconds (clean build)

## License

[GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html)

This project is free and open-source software licensed under GPL v3.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Roadmap

See [PLAN.md](PLAN.md) for the complete development roadmap and detailed feature plans.

## Credits

Inspired by Google Tasks and built with modern Rust tooling for maximum performance and cross-platform support.
