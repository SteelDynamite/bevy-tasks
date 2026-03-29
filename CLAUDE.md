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
WEBKIT_DISABLE_DMABUF_RENDERER=1 npm run tauri dev  # Run Tauri in dev mode (Wayland)
npm run tauri build                # Build for production
```

The CLI binary is named `bevy-tasks` (from the `bevy-tasks-cli` crate).

The Tauri dev server runs on port 1422 (`vite.config.ts` and `tauri.conf.json`).

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

### Tauri GUI structure

The GUI uses Svelte 5 runes mode (`$state`, `$derived`, `$effect`, `$props()`). Key UI patterns:

- **Sliding drawer**: Left panel (lists) slides with main content as one piece via `translateX`. 80vw wide.
- **Settings popup**: Floating overlay card with backdrop, not a sliding panel.
- **Workspace switcher**: Custom drop-up menu in drawer footer (left), settings gear (right).
- **Task animations**: Grid-rows `0fr`/`1fr` trick for smooth collapse/expand. Module-level `animateInIds` Set coordinates expand-in after toggle.
- **Inline editing**: Click task to edit, auto-save on blur, shared `editingTaskId` across instances.
- **Kebab menus**: Tasks, lists, and workspaces all use kebab → submenu pattern for delete.
- **New task**: FAB button opens bottom toast sheet (outside sliding container for fixed positioning).

### Current state (2026-03-29)

- **Phase 1** (Core + CLI): Complete
- **Phase 2** (WebDAV sync): Backend done, CLI done, GUI partially wired (empty credentials issue)
- **Phase 3** (GUI MVP): In progress — core task CRUD working, UI polished with animations

### GUI features done

- Task CRUD (create, read, update, delete)
- Task completion/restoration with animated transitions
- Drag-and-drop task reordering
- Inline task editing (auto-save on blur)
- Sliding lists drawer with checkmark selection
- Settings popup overlay
- Workspace switcher drop-up with add/remove
- Dark mode (GNOME-style neutral grays, cyan-blue accent)
- Completed tasks section with animated show/hide

### GUI features NOT yet done (CLI has these)

- Due date editing (model supports it, not exposed in UI)
- WebDAV setup flow (GUI passes empty credentials)
- Push-only / pull-only sync modes
- Sync status view
- Workspace retarget/migrate
- Group-by-due-date toggle
- Subtask hierarchy (data model exists, not used anywhere)
- List/workspace rename

## Roadmap

See `PLAN.md` for the 7-phase roadmap. Detailed API docs in `docs/API.md`, development practices in `docs/DEVELOPMENT.md`.
