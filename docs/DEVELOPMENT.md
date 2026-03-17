# Development Guide

## Getting Started

### Prerequisites

- Rust 1.70 or higher
- Git
- A text editor or IDE with Rust support (VS Code with rust-analyzer recommended)

### Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd bevy-tasks

# Build the project
cargo build

# Run tests
cargo test

# Run the CLI
cargo run -p bevy-tasks-cli -- --help
```

## Project Structure

```
bevy-tasks/
├── Cargo.toml                          # Workspace manifest
├── crates/
│   ├── bevy-tasks-core/                # Core library
│   │   ├── src/
│   │   │   ├── lib.rs                  # Library entry point
│   │   │   ├── models.rs               # Data models (Task, TaskList, etc.)
│   │   │   ├── config.rs               # Configuration (AppConfig, WorkspaceConfig)
│   │   │   ├── storage.rs              # Storage trait and filesystem implementation
│   │   │   ├── repository.rs           # Repository pattern (TaskRepository)
│   │   │   └── error.rs                # Error types
│   │   └── Cargo.toml
│   ├── bevy-tasks-cli/                 # CLI application
│   │   ├── src/
│   │   │   ├── main.rs                 # CLI entry point and command parsing
│   │   │   ├── output.rs               # Output formatting utilities
│   │   │   └── commands/
│   │   │       ├── mod.rs              # Commands module
│   │   │       ├── init.rs             # Initialize workspace
│   │   │       ├── workspace.rs        # Workspace management
│   │   │       ├── list.rs             # List management
│   │   │       ├── task.rs             # Task operations
│   │   │       └── group.rs            # Grouping commands
│   │   └── Cargo.toml
│   └── bevy-tasks-gui/                 # GUI application (Phase 3+)
│       ├── src/
│       │   └── main.rs                 # Placeholder
│       └── Cargo.toml
└── docs/
    ├── API.md                          # API documentation
    └── DEVELOPMENT.md                  # This file
```

## Development Workflow

### Running Tests

```bash
# Run all tests
cargo test

# Run tests for a specific crate
cargo test -p bevy-tasks-core

# Run a specific test
cargo test -p bevy-tasks-core test_create_and_list_tasks

# Run tests with output
cargo test -- --nocapture
```

### Building

```bash
# Debug build
cargo build

# Release build (optimized)
cargo build --release

# Build specific crate
cargo build -p bevy-tasks-cli
```

### Running the CLI in Development

```bash
# Run with cargo (recommended for development)
cargo run -p bevy-tasks-cli -- init ~/test-tasks --name test

# Run the compiled binary
./target/debug/bevy-tasks init ~/test-tasks --name test
```

## Code Style

### Formatting

We use rustfmt for code formatting:

```bash
# Format all code
cargo fmt

# Check formatting without modifying files
cargo fmt -- --check
```

### Linting

We use clippy for linting:

```bash
# Run clippy
cargo clippy

# Run clippy with all warnings
cargo clippy -- -W clippy::all
```

## Architecture Guidelines

### Core Library (`bevy-tasks-core`)

**Principles:**
- Pure Rust, no CLI dependencies
- Clear separation between models, storage, and repository
- Comprehensive error handling
- Well-tested (aim for >80% coverage)

**Adding a new feature:**

1. Start with the data model in `models.rs`
2. Update storage layer in `storage.rs` if needed
3. Add repository methods in `repository.rs`
4. Write tests
5. Update API documentation

### CLI (`bevy-tasks-cli`)

**Principles:**
- Thin layer over core library
- Clear command structure using clap
- User-friendly output with colored text
- Consistent error messages

**Adding a new command:**

1. Define command in `main.rs` using clap
2. Create command handler in `commands/` directory
3. Use `get_repository()` helper to access the core
4. Format output using `output.rs` helpers
5. Update README with usage examples

## Testing Strategy

### Unit Tests

Located in the same file as the code they test:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_something() {
        // Test code
    }
}
```

### Integration Tests

Located in `tests/` directories within each crate:

```rust
// crates/bevy-tasks-core/tests/integration_test.rs
use bevy_tasks_core::*;

#[test]
fn test_full_workflow() {
    // Test complete workflows
}
```

### Test Data

Use `tempfile` crate for temporary directories:

```rust
use tempfile::TempDir;

#[test]
fn test_with_temp_dir() {
    let temp_dir = TempDir::new().unwrap();
    let repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();
    // ... test code
}
```

## Common Tasks

### Adding a New Field to Task

1. Update `Task` struct in `models.rs`
2. Update `TaskFrontmatter` in `storage.rs`
3. Update markdown parsing/writing in `storage.rs`
4. Add migration logic if needed
5. Update tests
6. Update documentation

### Adding a New CLI Command

1. Add command to `Commands` enum in `main.rs`
2. Add match arm in `main()` function
3. Create command handler in `commands/` directory
4. Update README with usage example

### Debugging Storage Issues

Enable detailed logging:

```rust
// In test or development code
std::env::set_var("RUST_LOG", "debug");
```

Inspect the file system directly:

```bash
# Check metadata
cat ~/test-tasks/.metadata.json | jq

# Check list metadata
cat ~/test-tasks/My\ Tasks/.listdata.json | jq

# Check task file
cat ~/test-tasks/My\ Tasks/Example\ task.md
```

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- MAJOR: Incompatible API changes
- MINOR: New functionality, backwards compatible
- PATCH: Bug fixes, backwards compatible

### Creating a Release

1. Update version in all `Cargo.toml` files
2. Update `CHANGELOG.md`
3. Create git tag: `git tag v0.1.0`
4. Build release binaries: `cargo build --release`
5. Test release binaries
6. Push tag: `git push origin v0.1.0`

## Troubleshooting

### Cargo Build Fails

```bash
# Clean build artifacts
cargo clean

# Update dependencies
cargo update

# Check for errors
cargo check
```

### Tests Fail

```bash
# Run single test with output
cargo test test_name -- --nocapture

# Check for file system issues
ls -la ~/test-tasks
```

### CLI Command Doesn't Work

```bash
# Verify workspace configuration
cat ~/.config/bevy-tasks/config.json | jq

# Check current workspace
cargo run -p bevy-tasks-cli -- workspace list

# Initialize if needed
cargo run -p bevy-tasks-cli -- init ~/test-tasks --name test
```

## Contributing

### Before Submitting a PR

1. Run tests: `cargo test`
2. Format code: `cargo fmt`
3. Lint code: `cargo clippy`
4. Update documentation
5. Add tests for new features
6. Update CHANGELOG.md

### Commit Messages

Follow conventional commits:
- `feat: Add new feature`
- `fix: Fix bug`
- `docs: Update documentation`
- `test: Add tests`
- `refactor: Refactor code`

## Resources

- [Rust Book](https://doc.rust-lang.org/book/)
- [Cargo Book](https://doc.rust-lang.org/cargo/)
- [clap Documentation](https://docs.rs/clap/)
- [serde Documentation](https://serde.rs/)
- [PLAN.md](../PLAN.md) - Project roadmap
- [API.md](API.md) - API documentation
