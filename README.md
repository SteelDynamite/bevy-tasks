# Bevy Tasks

A local-first, cross-platform tasks application inspired by Google Tasks. Built with Rust for high performance and true native support across Windows, Linux, macOS, iOS, and Android.

## Core Principles

- **Local-First**: Your data, your folder, your control
- **Fast**: Sub-second startup, instant response
- **Cross-Platform**: Single codebase, all platforms
- **Flexible**: Multiple workspaces for different contexts (personal, shared, work, etc.)

## Features

### Phase 1 (Current) - Core Library & CLI MVP

- ✅ Full-featured task management backend
- ✅ Multiple workspace support
- ✅ Markdown-based task storage with YAML frontmatter (Obsidian-compatible)
- ✅ Manual task ordering
- ✅ Due date support
- ✅ Task grouping by due date
- ✅ Command-line interface (CLI)
- ✅ Comprehensive test coverage

### Coming Soon

- **Phase 2**: WebDAV sync for cross-device synchronization
- **Phase 3**: Desktop GUI with egui
- **Phase 4**: iOS and Android support
- **Phase 5**: Advanced GUI features
- **Phase 6**: Mobile platform-specific features
- **Phase 7**: Advanced features, imports, and collaboration

## Installation

### From Source

```bash
# Clone the repository
git clone <repository-url>
cd bevy-tasks

# Build the CLI
cargo build --release -p bevy-tasks-cli

# The binary will be at: target/release/bevy-tasks
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
# List all tasks in all lists
bevy-tasks list

# View tasks in a specific list
bevy-tasks list --list Work
```

### Complete and Delete Tasks

```bash
# Complete a task (use the task ID from list output)
bevy-tasks complete <task-id>

# Delete a task
bevy-tasks delete <task-id>
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
```

### List Management

```bash
# Create a new task list
bevy-tasks list create "Work"

# View all tasks
bevy-tasks list

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
bevy-tasks list --workspace shared
```

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

Application configuration is stored in platform-specific locations:

- **Windows**: `%APPDATA%\bevy-tasks\config.json`
- **Linux**: `~/.config/bevy-tasks/config.json`
- **macOS**: `~/Library/Application Support/bevy-tasks/config.json`

The configuration file contains your workspace definitions and current workspace selection.

## Architecture

Bevy Tasks uses a clean separation between backend and frontend:

- **bevy-tasks-core**: Core library with data models, storage, and repository pattern
- **bevy-tasks-cli**: Command-line interface (current)
- **bevy-tasks-gui**: Graphical user interface (coming in Phase 3)

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
```

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
cargo run -p bevy-tasks-cli -- list
```

## License

[GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html)

This project is free and open-source software licensed under GPL v3.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Roadmap

See [PLAN.md](PLAN.md) for the complete development roadmap and detailed feature plans.

## Credits

Inspired by Google Tasks and built with modern Rust tooling for maximum performance and cross-platform support.
