# Bevy Tasks

A **local-first, cross-platform tasks application** built with Rust. Inspired by Google Tasks, designed for speed and flexibility.

## Core Principles

- **Local-First**: Your data, your folder, your control
- **Fast**: Sub-second startup, instant response
- **Cross-Platform**: Single codebase, all platforms
- **Flexible**: Multiple workspaces for different contexts

## Project Structure

```
bevy-tasks/
├── Cargo.toml                    # Workspace definition
├── PLAN.md                       # Detailed project plan
├── README.md                     # This file
├── crates/
│   ├── bevy-tasks-core/          # Core library (backend)
│   ├── bevy-tasks-cli/           # CLI frontend
│   └── bevy-tasks-gui/           # GUI frontend (Phase 3+)
└── docs/
```

## Phase 1 Status: Core Library & CLI MVP ✅

Phase 1 implementation is complete with the following features:

### Core Library (`bevy-tasks-core`)
- ✅ Data models (Task, TaskList, AppConfig, WorkspaceConfig)
- ✅ Markdown file I/O with YAML frontmatter
- ✅ Local storage implementation
- ✅ Repository pattern with clean API
- ✅ Multiple workspace support
- ✅ Task ordering and grouping

### CLI (`bevy-tasks-cli`)
- ✅ Workspace management (init, add, list, switch, remove, retarget, migrate)
- ✅ Task list management (create, show, delete)
- ✅ Task operations (add, complete, delete, edit)
- ✅ Group-by-due-date toggle
- ✅ Support for `--workspace` flag on all commands

## Development Setup

### Prerequisites

- Rust 1.70+ (install from [rustup.rs](https://rustup.rs/))
- Git

### Build

```bash
# Clone and build
git clone <repository-url>
cd bevy-tasks
cargo build

# Run tests
cargo test -p bevy-tasks-core

# Run CLI
cargo run -p bevy-tasks-cli -- --help
```

## Quick Start

### Initialize your first workspace

```bash
# Initialize a new workspace
cargo run -p bevy-tasks-cli -- init ~/Documents/Tasks --name personal

# This creates:
# - A workspace named "personal" at ~/Documents/Tasks
# - A default list called "My Tasks"
# - Sets "personal" as the current workspace
```

### Add and manage tasks

```bash
# Add a task
cargo run -p bevy-tasks-cli -- add "Buy groceries"

# Add a task with due date
cargo run -p bevy-tasks-cli -- add "Review PR #123" --list "Work" --due "2025-11-15"

# List all tasks
cargo run -p bevy-tasks-cli -- list show

# Complete a task
cargo run -p bevy-tasks-cli -- complete <task-id>

# Edit a task (opens in $EDITOR)
cargo run -p bevy-tasks-cli -- edit <task-id>

# Delete a task
cargo run -p bevy-tasks-cli -- delete <task-id>
```

### Manage workspaces

```bash
# Add another workspace
cargo run -p bevy-tasks-cli -- workspace add shared ~/Dropbox/TeamTasks

# List workspaces
cargo run -p bevy-tasks-cli -- workspace list

# Switch workspace
cargo run -p bevy-tasks-cli -- workspace switch shared

# Use specific workspace for a command
cargo run -p bevy-tasks-cli -- add "Team meeting" --workspace shared
```

### Manage task lists

```bash
# Create a new list
cargo run -p bevy-tasks-cli -- list create "Work"

# Show tasks in a specific list
cargo run -p bevy-tasks-cli -- list show --list "Work"

# Delete a list
cargo run -p bevy-tasks-cli -- list delete "Work"
```

## Data Format

Tasks are stored as markdown files with YAML frontmatter (Obsidian-compatible):

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

## File System Structure

```
~/Documents/Tasks/           # User-selected folder
├── .metadata.json           # Global: list ordering, last opened list
├── My Tasks/                # Task list folder
│   ├── .listdata.json       # List metadata: task order, id, timestamps
│   ├── Buy groceries.md     # Individual task files
│   └── Call dentist.md
└── Work/
    ├── .listdata.json
    ├── Review PRs.md
    └── Team meeting prep.md
```

## Testing

Run the test suite:

```bash
# Run all tests
cargo test

# Run tests for specific crate
cargo test -p bevy-tasks-core

# Run tests with output
cargo test -- --nocapture
```

## What's Next?

- **Phase 2**: WebDAV sync for cross-device synchronization
- **Phase 3**: GUI with egui for desktop platforms
- **Phase 4**: Mobile support (iOS & Android)
- **Phase 5**: Advanced features and polish
- **Phase 6**: Platform-specific integrations
- **Phase 7**: Google Tasks importer and unique features

See [PLAN.md](PLAN.md) for detailed roadmap.

## License

[GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html)

This project is free and open-source software.
