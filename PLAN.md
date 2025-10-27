# Bevy Tasks - Project Plan

## Vision

A local-first, cross-platform tasks application inspired by Google Tasks, built with Bevy for high performance and future game-like UX polish. The application will launch near-instantly on all platforms and support both local file storage and WebDAV synchronization.

## Core Principles

1. **Local-First**: All data is stored locally by default, with optional sync
2. **Performance**: Sub-second cold start time on all platforms
3. **Cross-Platform**: Native support for Windows, Linux, macOS, iOS, and Android
4. **Privacy**: User data stays on their devices and chosen storage locations
5. **Future-Proof**: Built on Bevy to enable advanced UI/UX features later

## Target Platforms

- **Desktop**: Windows, Linux, macOS
- **Mobile**: iOS, Android

## Technology Stack

### Project Structure: Workspace with Backend/Frontend Separation

The project is organized as a Cargo workspace with three main crates:

1. **bevy-tasks-core** (Library): Pure Rust business logic, no UI dependencies
2. **bevy-tasks-cli** (Binary): Command-line interface for power users and testing
3. **bevy-tasks-gui** (Binary): Graphical frontend (framework TBD - see Frontend Comparison)

This separation provides:
- Clean architecture with testable core logic
- Multiple interfaces to the same backend
- Ability to develop and validate backend before frontend work
- CLI tool useful for automation, scripting, and CI/CD

### Backend/Core Library
- **serde**: Serialization/deserialization
- **pulldown-cmark** or **markdown**: Markdown parsing
- **serde_yaml**: YAML frontmatter parsing (Obsidian-style metadata)
- **directories**: Cross-platform path handling
- **tokio**: Async runtime for I/O operations
- **reqwest** + **dav-client**: WebDAV support
- **uuid**: Unique identifiers for tasks
- **chrono**: Date/time handling
- **anyhow**: Error handling

### CLI Frontend
- **clap**: Command-line argument parsing
- **colored**: Terminal colors for better UX
- **indicatif**: Progress bars for sync operations

### GUI Frontend
See "Frontend Framework Comparison" section below for detailed options.

### Performance Optimization
- **Lazy loading**: Load only visible data
- **Minimal dependencies**: Keep binary size small
- **Release optimizations**: LTO, strip symbols
- **Backend separation**: Core logic has zero UI overhead

## Architecture

### Data Model

Tasks are stored as individual `.md` (Markdown) files, with metadata in YAML frontmatter (Obsidian-compatible format).

```
Task File Format (my-task-name.md):
---
id: 550e8400-e29b-41d4-a716-446655440000
status: in-progress
due: 2025-11-15T14:00:00Z
created: 2025-10-26T10:00:00Z
updated: 2025-10-26T12:30:00Z
parent: 550e8400-e29b-41d4-a716-446655440001
position: 1
tags: [work, urgent]
---

Task description and notes go here in **markdown** format.

- Can include lists
- Rich formatting
- Links, etc.
```

**In-Memory Model**:
```rust
Task {
    id: Uuid,
    title: String,              // Derived from filename
    notes: String,              // Markdown content
    status: TaskStatus,         // From frontmatter
    due_date: Option<DateTime>, // From frontmatter
    created_at: DateTime,       // From frontmatter
    updated_at: DateTime,       // From frontmatter
    parent_id: Option<Uuid>,    // From frontmatter
    position: i32,              // From frontmatter
    tags: Vec<String>,          // From frontmatter
}

TaskList {
    id: Uuid,
    title: String,              // Derived from folder name
    tasks: Vec<Task>,
    created_at: DateTime,
    updated_at: DateTime,
    position: i32,
}

AppConfig {
    // Stored in platform-specific config location
    local_path: PathBuf,             // User-selected tasks folder (required)
    webdav_url: Option<String>,      // Optional WebDAV server
    webdav_credentials: Option<Credentials>,
    theme: Theme,
    last_sync: Option<DateTime>,
    window_size: Option<(u32, u32)>,
    last_opened_list: Option<Uuid>,
}
```

### Workspace Structure

```
bevy-tasks/
├── Cargo.toml                    # Workspace definition
├── PLAN.md
├── README.md
│
├── crates/
│   ├── bevy-tasks-core/          # Core library (backend)
│   │   ├── Cargo.toml
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── task.rs           # Task model
│   │   │   ├── task_list.rs      # TaskList model
│   │   │   ├── config.rs         # AppConfig
│   │   │   ├── repository.rs     # High-level API
│   │   │   ├── storage/
│   │   │   │   ├── mod.rs
│   │   │   │   ├── local.rs      # Local file I/O
│   │   │   │   ├── markdown.rs   # Markdown parser
│   │   │   │   └── webdav.rs     # WebDAV sync
│   │   │   └── error.rs          # Error types
│   │   └── tests/
│   │       ├── integration.rs
│   │       └── fixtures/
│   │
│   ├── bevy-tasks-cli/           # CLI frontend
│   │   ├── Cargo.toml
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   ├── commands/
│   │   │   │   ├── mod.rs
│   │   │   │   ├── add.rs
│   │   │   │   ├── list.rs
│   │   │   │   ├── complete.rs
│   │   │   │   ├── sync.rs
│   │   │   │   └── init.rs
│   │   │   └── ui.rs             # Terminal formatting
│   │   └── README.md
│   │
│   └── bevy-tasks-gui/           # GUI frontend
│       ├── Cargo.toml
│       ├── src/
│       │   ├── main.rs           # App entry point
│       │   ├── app.rs            # Framework setup
│       │   ├── ui/
│       │   │   ├── mod.rs
│       │   │   ├── screens/
│       │   │   │   ├── task_list.rs
│       │   │   │   ├── task_detail.rs
│       │   │   │   └── settings.rs
│       │   │   └── components/
│       │   │       ├── task_item.rs
│       │   │       ├── task_input.rs
│       │   │       └── list_selector.rs
│       │   └── state.rs          # UI state management
│       ├── assets/
│       │   ├── fonts/
│       │   └── icons/
│       └── README.md
│
└── docs/
    ├── API.md
    ├── CLI.md
    └── DEVELOPMENT.md
```

### Core Library API Design

The `bevy-tasks-core` library will expose a clean, high-level API:

```rust
// Main repository interface
pub struct TaskRepository {
    storage: Box<dyn Storage>,
}

impl TaskRepository {
    pub fn new(tasks_folder: PathBuf) -> Result<Self>;
    pub fn init(tasks_folder: PathBuf) -> Result<Self>;

    // Task operations
    pub fn create_task(&mut self, list_id: Uuid, task: Task) -> Result<Task>;
    pub fn get_task(&self, id: Uuid) -> Result<Task>;
    pub fn update_task(&mut self, task: Task) -> Result<()>;
    pub fn delete_task(&mut self, id: Uuid) -> Result<()>;
    pub fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>>;

    // List operations
    pub fn create_list(&mut self, name: String) -> Result<TaskList>;
    pub fn get_lists(&self) -> Result<Vec<TaskList>>;
    pub fn delete_list(&mut self, id: Uuid) -> Result<()>;

    // Sync operations
    pub fn sync_push(&mut self) -> Result<SyncResult>;
    pub fn sync_pull(&mut self) -> Result<SyncResult>;
    pub fn sync_status(&self) -> Result<SyncStatus>;
}

// Storage trait for local and WebDAV implementations
pub trait Storage {
    fn read_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task>;
    fn write_task(&mut self, list_id: Uuid, task: &Task) -> Result<()>;
    // ... more methods
}
```

### Storage Strategy

#### Local Storage
- **Location**: **User must select a folder** on first run
  - Can be anywhere with read/write permissions
  - Examples: `~/Documents/Tasks`, `~/Dropbox/Tasks`, `D:\My Tasks`
  - Users can change location later in settings
  - **No hidden default directories** - full user control and visibility
- **App Configuration Storage** (separate from task data):
  - Windows: `%APPDATA%/bevy-tasks/config.json`
  - Linux: `~/.config/bevy-tasks/config.json`
  - macOS: `~/Library/Application Support/bevy-tasks/config.json`
  - iOS: App sandbox preferences
  - Android: App preferences
  - Stores: selected folder path, theme, last sync time, window position
- **Format**: Markdown files with YAML frontmatter (Obsidian-compatible)
- **Structure**:
  ```
  ~/Documents/Tasks/           # User-selected folder
  ├── .bevy-tasks/
  │   └── metadata.json        # List ordering, sync state
  ├── My Tasks/                # Task list folder
  │   ├── Buy groceries.md
  │   ├── Call dentist.md
  │   └── Project X/           # Subtask folder (optional)
  │       └── Design mockup.md
  └── Work/                    # Another task list
      ├── Review PRs.md
      └── Team meeting prep.md
  ```

**First Run Experience**:
- CLI: `bevy-tasks init ~/Documents/Tasks` (user specifies path)
- GUI: Folder picker dialog on first launch
- Mobile: Folder picker with suggested locations (Documents, iCloud Drive, etc.)

**Benefits of User-Selected Storage**:
- **Full transparency**: Users can see exactly where their data is
- **Easy backup**: Users can backup the folder however they want (Time Machine, cloud sync, etc.)
- **Portable**: Move folder between machines, cloud drives, USB drives
- **No lock-in**: Data is in plain markdown, accessible without the app
- **Git-friendly**: Users can version control their tasks folder
- **Compatible with other tools**: Use with Obsidian, Logseq, VS Code, etc.
- **Multiple vaults**: Users can have separate task folders for work/personal
- **User choice**: Dropbox, iCloud, OneDrive, local folder - user decides

#### WebDAV Sync
- **Conflict Resolution**: Last-write-wins with timestamp
- **Sync Strategy**:
  - On app start (if connected)
  - On background timer (every 5 minutes when active)
  - On task modification (debounced)
- **Offline Support**: All operations work offline, sync when online

### Performance Strategy

#### Fast Startup Requirements
1. **Minimal initialization**: Load only essential systems
2. **Lazy data loading**: Load visible tasks first
3. **Background operations**: Non-critical data and sync after first render
4. **Efficient file I/O**: Stream large markdown files
5. **Small binary size**: Minimal dependencies in core library

#### Startup Sequence (egui GUI)
1. Initialize eframe window (< 50ms)
2. Load config from disk (< 20ms)
3. Render empty UI (first frame < 100ms)
4. Load current task list in background
5. Update UI as tasks load (incremental rendering)
6. Start WebDAV sync in background (if configured)

**Target**: < 200ms cold start on desktop

#### Memory Optimization
- Use `Vec` instead of `HashMap` for small collections
- Limit rendered tasks to visible viewport
- Lazy load task lists (only load selected list)
- Stream markdown parsing for large files

## Feature Roadmap

### Phase 1: Core Library & CLI MVP
**Goal**: Build and validate the backend with a functional CLI

**Features**:
- [ ] Project workspace setup (bevy-tasks-core, bevy-tasks-cli, bevy-tasks-gui)
- [ ] Data models (Task, TaskList, AppConfig)
- [ ] Markdown file I/O with YAML frontmatter parsing
- [ ] Local storage implementation
- [ ] Repository pattern and public API
- [ ] CLI: init, add, list, complete, delete, edit commands
- [ ] CLI: Basic task listing and formatting
- [ ] Comprehensive unit and integration tests

**Deliverables**:
- `bevy-tasks-core` library with stable API
- Functional CLI that can manage tasks via command line
- Data persists as Obsidian-compatible .md files
- Well-tested backend (>80% coverage)

**CLI Example**:
```bash
# First run: initialize tasks folder
bevy-tasks init ~/Documents/Tasks

# Or use a cloud-synced folder
bevy-tasks init ~/Dropbox/Tasks

# Then use normally
bevy-tasks add "Buy groceries" --list "Personal"
bevy-tasks list
bevy-tasks complete <task-id>

# Change folder location
bevy-tasks config set-folder ~/new/location
```

### Phase 2: WebDAV Sync (Backend + CLI)
**Goal**: Enable cross-device synchronization via CLI

**Features**:
- [ ] WebDAV client implementation in core library
- [ ] Credential storage (platform keychain)
- [ ] Bi-directional sync (push/pull/auto)
- [ ] Conflict resolution (last-write-wins)
- [ ] Offline queue for pending operations
- [ ] CLI: sync setup, push, pull, status commands
- [ ] CLI: Progress indicators for sync operations

**Deliverables**:
- Working WebDAV sync in backend
- CLI can sync with remote WebDAV server
- Reliable conflict resolution tested with real servers (Nextcloud, ownCloud)

**CLI Example**:
```bash
bevy-tasks sync --setup
bevy-tasks sync --push
bevy-tasks sync --pull
bevy-tasks sync --status
```

### Phase 3: GUI MVP (Desktop)
**Goal**: Build graphical interface on desktop platforms

**Frontend Decision**: Choose frontend framework (see Frontend Comparison section)

**Features**:
- [ ] GUI framework integration
- [ ] Basic task list view
- [ ] Create/edit/delete tasks
- [ ] Mark tasks complete
- [ ] Settings screen (change folder location, WebDAV config)
- [ ] Desktop support (Windows, Linux, macOS)
- [ ] Sync status indicators

**Deliverables**:
- Functional desktop GUI app
- Sub-second startup time
- Clean, minimal UI
- Feature parity with CLI

### Phase 4: GUI Advanced Features (Desktop)
**Goal**: Feature parity with Google Tasks

**Features**:
- [ ] Multiple task lists (folders)
- [ ] Switch between lists
- [ ] Subtasks support
- [ ] Due dates with date picker
- [ ] Rich markdown editor for task notes
- [ ] Drag & drop reordering
- [ ] Move tasks between lists
- [ ] Change storage folder location in settings
- [ ] Keyboard shortcuts
- [ ] Search functionality

**Deliverables**:
- Full-featured desktop task manager
- Polished UX
- Keyboard-driven workflow

### Phase 5: Mobile Support
**Goal**: Deploy to iOS and Android

**Features**:
- [ ] Touch-optimized UI
- [ ] iOS build pipeline
- [ ] Android build pipeline
- [ ] Mobile-specific UX (swipe gestures, pull-to-refresh)
- [ ] Background sync on mobile
- [ ] Mobile file system integration
- [ ] Share extension (share to tasks)
- [ ] Native mobile feel

**Deliverables**:
- Working iOS app
- Working Android app
- Consistent UX across mobile and desktop

### Phase 6: Polish & Advanced Features
**Goal**: Differentiate from Google Tasks, add unique features

**Features**:
- [ ] Themes and customization
- [ ] Advanced animations and transitions (if using Bevy)
- [ ] Full-text search across tasks
- [ ] Filters and smart lists
- [ ] Task templates
- [ ] Recurring tasks
- [ ] Statistics and insights
- [ ] Export/import (backup)
- [ ] Plugin system for extensions (optional)
- [ ] Game-like achievements (optional, if using Bevy)

**Deliverables**:
- Polished, delightful UX
- Unique features not in Google Tasks
- Distribution to all app stores

## Development Guidelines

### Performance Budgets
- **Cold start**: < 500ms on desktop, < 1s on mobile
- **First render**: < 100ms
- **Task creation**: < 50ms
- **Sync operation**: < 2s for typical dataset (< 1000 tasks)
- **Memory usage**: < 50MB on mobile, < 100MB on desktop

### Testing Strategy
- **Unit tests**: Data models and business logic
- **Integration tests**: Storage layer operations
- **E2E tests**: Critical user flows
- **Performance tests**: Startup time, large datasets
- **Platform tests**: Verify each platform build

### Build & Release
- **CI/CD**: GitHub Actions for all platforms
- **Initial Distribution**:
  - **Desktop**: Direct downloads and sideloading
    - Linux: AppImage, .tar.gz
    - macOS: DMG
    - Windows: MSI, portable .exe
  - **Mobile**: Sideloading only
    - iOS: .ipa for TestFlight/direct install
    - Android: .apk
- **Future Distribution Channels** (Phase 5+):
  - **F-Droid**: FOSS Android app store
  - **Flathub**: Linux Flatpak repository
  - **Google Play Store**: Android
  - **Apple App Store**: iOS and macOS
  - **Microsoft Store**: Windows
- **Version scheme**: Semantic versioning (0.1.0 → 1.0.0)
- **Release notes**: Auto-generated from commits

## Technical Challenges & Solutions

### Challenge 1: Fast Startup with GUI
**Problem**: UI initialization can add overhead

**Solutions (egui)**:
- Use eframe with minimal features
- Defer loading of non-visible data
- Initialize window before loading tasks
- Profile startup and optimize hot paths
- Keep core library dependency-light

### Challenge 2: Mobile Platform Support
**Problem**: iOS and Android have different requirements

**Solutions**:
- Use conditional compilation for platform-specific code
- Test early and often on real devices
- Follow platform guidelines (iOS HIG, Material Design)
- Use platform-specific file pickers and sharing

### Challenge 3: WebDAV Reliability
**Problem**: Network can be unreliable, auth can be complex

**Solutions**:
- Implement robust retry logic with exponential backoff
- Cache credentials securely (see Authentication Options below)
- Queue operations when offline
- Provide clear sync status to user
- Support multiple WebDAV servers (Nextcloud, ownCloud, etc.)

### Challenge 4: Data Migration
**Problem**: Schema changes need to preserve user data

**Solutions**:
- Version frontmatter schema from day one
- Write migration scripts for each version bump
- Markdown format is naturally forward/backward compatible
- Users handle their own backups (external to app)
- Migration can be done in-place by updating frontmatter

## Frontend Framework Decision

**Decision Made**: Hybrid approach with **egui** for Phase 3, optional **Bevy** migration in Phase 6.

### Phase 3-5: egui (Immediate Mode GUI)

**Why egui for MVP?**
- ✅ Fast development with rich built-in widgets
- ✅ Excellent text editing and form support out of the box
- ✅ Small binary size (~2-3MB stripped)
- ✅ Fast startup time (100-200ms)
- ✅ Mature and stable
- ✅ Simple immediate-mode API
- ✅ Cross-platform (desktop primary, mobile possible)
- ✅ Easy integration with `bevy-tasks-core`

**Trade-offs**:
- ⚠️ Less flexibility for custom animations
- ⚠️ Mobile support less mature (but improving)
- ⚠️ Not as "game-like" polish potential

### Phase 6 (Optional): Migration to Bevy

**If you want game-like polish later:**
- ✅ Full control over animations and rendering
- ✅ Unique, polished look beyond standard apps
- ✅ Better mobile support (iOS/Android)
- ✅ ECS architecture for complex interactions
- ✅ Backend stays identical (clean separation!)

**Why this works:**
The `bevy-tasks-core` library is UI-framework agnostic, so switching from egui to Bevy only requires rewriting the `bevy-tasks-gui` crate. All business logic, file I/O, sync, and testing remains unchanged.

This approach de-risks the project: validate the concept with egui, then optionally invest in custom polish with Bevy if the app takes off.

## Dependencies

### Workspace Structure (Cargo.toml)
```toml
[workspace]
members = [
    "crates/bevy-tasks-core",
    "crates/bevy-tasks-cli",
    "crates/bevy-tasks-gui",
]
resolver = "2"

[workspace.dependencies]
# Shared dependencies
serde = { version = "1.0", features = ["derive"] }
uuid = { version = "1.0", features = ["serde", "v4"] }
chrono = { version = "0.4", features = ["serde"] }
anyhow = "1.0"
tokio = { version = "1.40", features = ["full"] }
```

### Core Library (bevy-tasks-core/Cargo.toml)
```toml
[package]
name = "bevy-tasks-core"
version = "0.1.0"
edition = "2024"

[dependencies]
serde = { workspace = true }
serde_json = "1.0"
serde_yaml = "0.9"  # YAML frontmatter parsing
pulldown-cmark = "0.12"  # Markdown parsing
uuid = { workspace = true }
chrono = { workspace = true }
directories = "5.0"  # Cross-platform paths
tokio = { workspace = true }
anyhow = { workspace = true }

# WebDAV support
reqwest = { version = "0.12", features = ["json", "rustls-tls"] }
# TODO: Evaluate dav-client or implement custom WebDAV

# Credential storage
keyring = "3.0"  # Cross-platform keychain

[dev-dependencies]
tempfile = "3.0"  # For testing file operations
```

### CLI (bevy-tasks-cli/Cargo.toml)
```toml
[package]
name = "bevy-tasks-cli"
version = "0.1.0"
edition = "2024"

[[bin]]
name = "bevy-tasks"
path = "src/main.rs"

[dependencies]
bevy-tasks-core = { path = "../bevy-tasks-core" }
clap = { version = "4.5", features = ["derive", "env"] }
colored = "2.0"  # Terminal colors
indicatif = "0.17"  # Progress bars
anyhow = { workspace = true }
tokio = { workspace = true }
```

### GUI (bevy-tasks-gui/Cargo.toml)
```toml
[package]
name = "bevy-tasks-gui"
version = "0.1.0"
edition = "2024"

[dependencies]
bevy-tasks-core = { path = "../bevy-tasks-core" }
anyhow = { workspace = true }

# egui for Phase 3-5
eframe = "0.31"  # egui framework with native windowing
egui = "0.31"    # Core egui library

# TODO Phase 6: Consider migration to Bevy for game-like polish
# bevy = { version = "0.16", default-features = false, features = ["bevy_ui", "bevy_render", "bevy_winit"] }

# Platform-specific
[target.'cfg(target_os = "android")'.dependencies]
# Android-specific deps (Phase 5)

[target.'cfg(target_os = "ios")'.dependencies]
# iOS-specific deps (Phase 5)
```

## Getting Started

### Prerequisites
- Rust 1.75+ (2024 edition)
- Platform-specific tools (for mobile builds later):
  - **iOS**: macOS + Xcode
  - **Android**: Android SDK + NDK

### Development Setup
```bash
# Clone repository
git clone <repository-url>
cd bevy-tasks

# Build all workspace members
cargo build

# Run tests for core library
cargo test -p bevy-tasks-core

# Run CLI
cargo run -p bevy-tasks-cli -- --help
cargo run -p bevy-tasks-cli -- init ~/test-tasks

# Run GUI (once implemented)
cargo run -p bevy-tasks-gui

# Build for release
cargo build --release -p bevy-tasks-cli
cargo build --release -p bevy-tasks-gui

# Run all tests
cargo test --workspace
```

### Development Workflow (Phase 1)

1. **Start with Core Library**:
```bash
cd crates/bevy-tasks-core
cargo test --watch  # with cargo-watch
```

2. **Build CLI to test backend**:
```bash
cd crates/bevy-tasks-cli
cargo run -- init ~/Documents/TestTasks
cargo run -- add "Test task"
cargo run -- list
```

3. **Iterate on API**:
- Add features to core library
- Test via CLI
- Write integration tests
- Document public API

4. **Add GUI later** (Phase 3):
```bash
cd crates/bevy-tasks-gui
cargo run
```

## Questions & Decisions

### 1. Authentication for WebDAV Sync

#### Option A: Platform Keychain/Keyring
**Implementation**: Use `keyring` crate for cross-platform credential storage

**Pros**:
- Most secure option
- OS-managed encryption
- Follows platform security best practices
- Auto-locks with system
- Works on all platforms:
  - Windows: Credential Manager
  - macOS: Keychain
  - Linux: Secret Service API (gnome-keyring/kwallet)
  - iOS: Keychain
  - Android: Keystore

**Cons**:
- Requires user to unlock keychain
- May prompt for permissions
- Linux requires D-Bus and secret service

**Security**: ⭐⭐⭐⭐⭐

#### Option B: Encrypted Local Storage
**Implementation**: Encrypt credentials in config file using a master password or device key

**Pros**:
- Works offline always
- No external dependencies
- Full control over encryption

**Cons**:
- Need to manage encryption keys
- Vulnerable if key is compromised
- Need to prompt user for password
- Harder to implement correctly

**Security**: ⭐⭐⭐ (if done right)

#### Option C: App-Generated Token + Keychain
**Implementation**: User authenticates once via OAuth/app-specific password, store token in keychain

**Pros**:
- More secure than passwords
- Supports modern auth flows
- Can revoke tokens
- Works with Nextcloud, ownCloud app passwords

**Cons**:
- Requires OAuth flow implementation
- More complex initial setup
- Depends on server support

**Security**: ⭐⭐⭐⭐⭐

#### Option D: Store Username + Prompt for Password
**Implementation**: Store username in config, prompt for password on each sync

**Pros**:
- Simple implementation
- No credential storage
- Maximum security

**Cons**:
- Terrible UX
- Not practical for background sync
- Users will hate it

**Security**: ⭐⭐⭐⭐⭐ (but unusable)

#### Recommendation
**Primary**: Option A (Platform Keychain) using the `keyring` crate
- Store WebDAV username + password in system keychain
- Key: `com.bevy-tasks.webdav.{server-domain}`
- Graceful fallback if keychain is unavailable

**Fallback**: Option B (Encrypted storage) for platforms where keychain fails
- Use ChaCha20-Poly1305 for encryption
- Derive key from device identifier + app secret

**Future**: Option C (Token-based) for servers that support it
- Implement OAuth flow for Nextcloud/ownCloud
- Store tokens in keychain

---

### 3. Backup Strategy

**Decision**: User-managed backups via external tools

**Rationale**:
- Markdown format is already backup-friendly
- Users can use existing tools:
  - Git for version control
  - Dropbox/Google Drive/OneDrive for cloud backup
  - Time Machine (macOS) / File History (Windows)
  - rsync, rclone, etc.
- WebDAV itself serves as a backup when enabled
- Keeps app simple and focused

**App Responsibilities**:
- Don't corrupt data
- Write atomically (temp file + rename)
- Graceful handling of sync conflicts
- Clear documentation on backup best practices

**Optional Future Feature**:
- Export all tasks to single file (.zip of markdown)
- Import from backup
- Git integration for automatic versioning

## Resources

- [Bevy Documentation](https://bevyengine.org/)
- [Bevy Mobile Examples](https://github.com/bevyengine/bevy/tree/main/examples/mobile)
- [WebDAV RFC 4918](https://datatracker.ietf.org/doc/html/rfc4918)
- [Google Tasks API](https://developers.google.com/tasks) (for feature reference)

## License

To be determined.

---

**Last Updated**: 2025-10-27
**Document Version**: 2.2
**Status**: Ready to Implement - User-Controlled Storage
