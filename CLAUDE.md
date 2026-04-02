# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Onyx is a local-first, cross-platform task management app built in Rust. Tasks are stored as markdown files with YAML frontmatter in user-selected folders. The GUI uses Tauri v2 (Svelte 5 + Tailwind CSS 4) in `apps/tauri/`.

## Build & Test Commands

```bash
cargo build                        # Build all crates
cargo build -p onyx-cli      # Build CLI only
cargo test                         # Run all tests
cargo test -p onyx-core      # Run core library tests only
cargo run -p onyx-cli -- <args>  # Run CLI with arguments

# Tauri GUI
cd apps/tauri && npm install       # Install frontend dependencies
WEBKIT_DISABLE_DMABUF_RENDERER=1 npm run tauri dev  # Run Tauri in dev mode (Wayland)
npm run tauri build                # Build for production
```

The CLI binary is named `onyx` (from the `onyx-cli` crate).

The Tauri dev server runs on port 1422 (`vite.config.ts` and `tauri.conf.json`).

## Architecture

Two-crate workspace (`resolver = "2"`, edition 2021) plus a Tauri app:

- **onyx-core** — Pure Rust library. Storage trait with `FileSystemStorage` implementation, `TaskRepository` (main API), data models, config, error types. No CLI/UI dependencies. `keyring` feature-gated behind `keyring-storage` (default on) for Android compatibility.
- **onyx-cli** — CLI frontend using clap. Commands are in `src/commands/` (init, workspace, list, task, group). Output formatting in `src/output.rs`.
- **apps/tauri/** — Tauri v2 GUI. Svelte 5 frontend in `src/`, Rust backend in `src-tauri/` with Tauri commands that call into `onyx-core`. `notify` crate feature-gated for Android.
- **apps/flutter/** — Flutter GUI. Dart frontend in `lib/src/`, Rust backend in `rust/` via flutter_rust_bridge FFI into `onyx-core`.

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

### Current state (2026-04-01)

- **Phase 1** (Core + CLI): Complete
- **Phase 2** (WebDAV sync): Backend done, CLI done, GUI wired (settings auto-populates credentials)
- **Phase 3** (GUI MVP): Complete — both Tauri and Flutter GUIs at feature parity
- **Phase 4** (Mobile): Tauri Android cfg-gated, needs `tauri android init` + build

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
- Due date picker/editor (DateTimePicker in new task + task detail); `has_time: bool` field tracks whether time is set
- Move task between lists (kebab menu → "Move to..." submenu)
- List rename (inline input via list kebab menu)
- Group-by-due-date toggle per list (list kebab menu)
- Keyboard shortcuts (Escape priority chain: settings → detail → drawer → menus)
- WebDAV setup flow (settings auto-populates URL/credentials from config + keychain)
- File watcher (notify crate, 500ms debounce, auto-reloads on external changes)
- Setup screen with window dragging + "Open Existing Folder" option
- Sync status indicators (last-sync time + upload/download counts chip)
- Push/pull/full sync mode selection (session-only, in settings)
- Desktop packaging (Linux: AppImage + .deb)
- Flutter GUI at full parity with Tauri (WebDAV UI, has_time, sync status, sync mode)
- Tauri desktop-only deps (notify, keyring) feature-gated for Android compilation

### GUI features NOT yet done

- Workspace retarget/migrate
- Subtask hierarchy (data model exists, not used anywhere)
- Search/filter tasks
- Desktop packaging for Windows and macOS

## Roadmap

See `PLAN.md` for the 7-phase roadmap. Detailed API docs in `docs/API.md`, development practices in `docs/DEVELOPMENT.md`.
