# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bevy Tasks is a local-first, cross-platform task management app built in Rust. Tasks are stored as markdown files with YAML frontmatter in user-selected folders. The GUI uses Tauri v2 (Svelte 5 + Tailwind CSS 4) in `apps/tauri/`.

## Build & Test Commands

```bash
cargo build                        # Build all crates
cargo build -p bevy-tasks-cli      # Build CLI only
cargo test                         # Run all tests
cargo test -p bevy-tasks-core      # Run core library tests only
cargo run -p bevy-tasks-cli -- <args>  # Run CLI with arguments

# Tauri GUI
cd apps/tauri && npm install       # Install frontend dependencies
npm run tauri dev                  # Run Tauri in dev mode
npm run tauri build                # Build for production
```

The CLI binary is named `bevy-tasks` (from the `bevy-tasks-cli` crate).

## Architecture

Two-crate workspace (`resolver = "2"`, edition 2021) plus a Tauri app:

- **bevy-tasks-core** — Pure Rust library. Storage trait with `FileSystemStorage` implementation, `TaskRepository` (main API), data models, config, error types. No CLI/UI dependencies.
- **bevy-tasks-cli** — CLI frontend using clap. Commands are in `src/commands/` (init, workspace, list, task, group). Output formatting in `src/output.rs`.
- **apps/tauri/** — Tauri v2 GUI. Svelte 5 frontend in `src/`, Rust backend in `src-tauri/` with Tauri commands that call into `bevy-tasks-core`.

### Key patterns

- **Storage trait** (`storage.rs`): Strategy pattern for task persistence. `FileSystemStorage` reads/writes markdown files with YAML frontmatter and JSON metadata files.
- **Repository** (`repository.rs`): `TaskRepository` wraps a `Storage` impl and provides the public API for task/list CRUD, ordering, and grouping. Tests live here.
- **Config** (`config.rs`): `AppConfig` manages named workspaces with paths. Stored in platform-specific config dirs via the `directories` crate.

### On-disk format

Workspaces are plain folders. Each task list is a subfolder containing `.listdata.json` (metadata/ordering) and one `.md` file per task. The workspace root has `.metadata.json` for list ordering.

## Roadmap

See `PLAN.md` for the 7-phase roadmap. Phase 1 is complete. Detailed API docs in `docs/API.md`, development practices in `docs/DEVELOPMENT.md`.
