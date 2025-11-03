# Bevy Tasks - Project Plan

## Vision

A **local-first, cross-platform tasks application** inspired by Google Tasks. Built with Rust for high performance and true native support across Windows, Linux, macOS, iOS, and Android.

**Core Principles**:
- **Local-First**: Your data, your folder, your control
- **Fast**: Sub-second startup, instant response
- **Cross-Platform**: Single codebase, all platforms

**Data Format**: Tasks stored as markdown files with YAML frontmatter (Obsidian-compatible)
**Storage**: User selects folder location (e.g., `~/Documents/Tasks`, `~/Dropbox/Tasks`)
**Sync**: Optional WebDAV for cross-device synchronization
**Architecture**: Backend/frontend separation with CLI-first development

---

## Resources

- [Bevy Documentation](https://bevyengine.org/)
- [egui Documentation](https://docs.rs/egui/)
- [WebDAV RFC 4918](https://datatracker.ietf.org/doc/html/rfc4918)
- [Google Tasks API](https://developers.google.com/tasks) (for importer reference)

---

## Phase 1: Core Library & CLI MVP

**Goal**: Build and validate the backend with a functional CLI

### Why CLI First?
- Test backend thoroughly before GUI complexity
- CLI useful for power users and automation
- Clean API boundaries
- Easy to write comprehensive tests

### Architecture

#### Cargo Workspace Structure
```
bevy-tasks/
├── Cargo.toml                    # Workspace definition
├── PLAN.md
├── README.md
├── crates/
│   ├── bevy-tasks-core/          # Core library (backend)
│   ├── bevy-tasks-cli/           # CLI frontend
│   └── bevy-tasks-gui/           # GUI frontend (Phase 3+)
└── docs/
```

#### Data Model

Tasks are stored as individual `.md` files with YAML frontmatter:

```markdown
---
id: 550e8400-e29b-41d4-a716-446655440000
status: backlog
due: 2025-11-15T14:00:00Z
created: 2025-10-26T10:00:00Z
updated: 2025-10-26T12:30:00Z
parent: 550e8400-e29b-41d4-a716-446655440001
---

Task description and notes go here in **markdown** format.

- Can include lists
- Rich formatting
- Links, etc.
```

**Note**: No `position` field in frontmatter - task ordering is stored in the list's `.listdata.json` file. This means reordering tasks only requires updating one file.

**TaskStatus values**:
- `backlog` - Task not yet completed
- `completed` - Task is done

**In-Memory Model**:
```rust
Task {
    id: Uuid,
    title: String,              // Derived from filename
    notes: String,              // Markdown content
    status: TaskStatus,         // Backlog or Completed
    due_date: Option<DateTime>,
    created_at: DateTime,
    updated_at: DateTime,
    parent_id: Option<Uuid>,    // For subtasks
}

enum TaskStatus {
    Backlog,     // Not yet completed
    Completed,   // Done
}

TaskList {
    id: Uuid,
    title: String,              // Derived from folder name
    tasks: Vec<Task>,           // Ordered according to sort_order preference
    created_at: DateTime,
    updated_at: DateTime,
    sort_order: SortOrder,      // How to sort: Manual or ByDueDate
}

enum SortOrder {
    Manual,      // Use task_order from .listdata.json
    ByDueDate,   // Sort by due_date field (tasks without due dates at end)
}

AppConfig {
    local_path: PathBuf,
}
```

#### File System Structure

```
~/Documents/Tasks/           # User-selected folder
├── .metadata.json           # Global: list ordering, last opened list
├── My Tasks/                # Task list folder
│   ├── .listdata.json       # List metadata: task order, id, timestamps
│   ├── Buy groceries.md
│   └── Call dentist.md
└── Work/                    # Another task list
    ├── .listdata.json
    ├── Review PRs.md
    └── Team meeting prep.md
```

**`.metadata.json` (root level)**:
```json
{
  "version": 1,
  "list_order": ["list-uuid-1", "list-uuid-2"],
  "last_opened_list": "list-uuid-1"
}
```

**`.listdata.json` (per list)**:
```json
{
  "id": "list-uuid-1",
  "created_at": "2025-10-26T10:00:00Z",
  "updated_at": "2025-10-27T14:30:00Z",
  "sort_order": "manual",
  "task_order": [
    "task-uuid-1",
    "task-uuid-2",
    "task-uuid-3"
  ]
}
```

**Sort Order Options**:
- `"manual"` - Tasks ordered by hand (uses `task_order` array)
- `"by_due_date"` - Tasks automatically sorted by due date (tasks without due dates appear at end)

When `sort_order` is `"manual"`, the `task_order` array defines the sequence. When `sort_order` is `"by_due_date"`, tasks are sorted dynamically and `task_order` is ignored.

**Benefits**:
- **Two sort modes**: Manual ordering or automatic by due date
- **Ordering in list metadata**: Changing manual order only touches `.listdata.json`
- **Portable lists**: Copy/move a list folder and its metadata stays with it
- **Clean structure**: No nested hidden folders, just hidden files
- **WebDAV-friendly**: Syncing a list syncs its metadata naturally

**App Configuration** (separate from task data):
- Windows: `%APPDATA%/bevy-tasks/config.json`
- Linux: `~/.config/bevy-tasks/config.json`
- macOS: `~/Library/Application Support/bevy-tasks/config.json`

#### Core Library API

```rust
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

    // Task ordering (modifies .listdata.json)
    pub fn reorder_task(&mut self, list_id: Uuid, task_id: Uuid, new_position: usize) -> Result<()>;
    pub fn get_task_order(&self, list_id: Uuid) -> Result<Vec<Uuid>>;

    // Sort preference (modifies .listdata.json)
    pub fn set_sort_order(&mut self, list_id: Uuid, sort_order: SortOrder) -> Result<()>;
    pub fn get_sort_order(&self, list_id: Uuid) -> Result<SortOrder>;
}

pub trait Storage {
    fn read_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task>;
    fn write_task(&mut self, list_id: Uuid, task: &Task) -> Result<()>;
    // ... more methods
}
```

### Dependencies

**Workspace Cargo.toml**:
```toml
[workspace]
members = [
    "crates/bevy-tasks-core",
    "crates/bevy-tasks-cli",
    "crates/bevy-tasks-gui",
]
resolver = "2"

[workspace.dependencies]
serde = { version = "1.0", features = ["derive"] }
uuid = { version = "1.0", features = ["serde", "v4"] }
chrono = { version = "0.4", features = ["serde"] }
anyhow = "1.0"
tokio = { version = "1.40", features = ["full"] }
```

**bevy-tasks-core/Cargo.toml**:
```toml
[package]
name = "bevy-tasks-core"
version = "0.1.0"
edition = "2024"

[dependencies]
serde = { workspace = true }
serde_json = "1.0"
serde_yaml = "0.9"        # YAML frontmatter
pulldown-cmark = "0.12"   # Markdown parsing
uuid = { workspace = true }
chrono = { workspace = true }
directories = "5.0"
anyhow = { workspace = true }

[dev-dependencies]
tempfile = "3.0"
```

**bevy-tasks-cli/Cargo.toml**:
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
colored = "2.0"
indicatif = "0.17"
anyhow = { workspace = true }
tokio = { workspace = true }
```

### Features

- [ ] Cargo workspace setup
- [ ] Data models (Task, TaskList, AppConfig)
- [ ] Markdown file I/O with YAML frontmatter parsing
- [ ] Local storage implementation
- [ ] Repository pattern and public API
- [ ] CLI: `init` command (user selects folder)
- [ ] CLI: `add` command (create tasks)
- [ ] CLI: `list` command (view tasks)
- [ ] CLI: `complete` command (mark done)
- [ ] CLI: `delete` command (remove tasks)
- [ ] CLI: `edit` command (modify tasks)
- [ ] Two sort modes: manual ordering and by due date
- [ ] CLI: `sort` command (switch between manual/by-due-date)
- [ ] Comprehensive unit and integration tests (>80% coverage)

### CLI Usage Examples

```bash
# First run: initialize tasks folder
bevy-tasks init ~/Documents/Tasks

# Or use a cloud-synced folder
bevy-tasks init ~/Dropbox/Tasks

# Then use normally
bevy-tasks add "Buy groceries" --list "Personal"
bevy-tasks list
bevy-tasks list --list "Work"
bevy-tasks complete <task-id>
bevy-tasks edit <task-id>
bevy-tasks delete <task-id>

# Change folder location later
bevy-tasks config set-folder ~/new/location

# Sort order
bevy-tasks sort manual --list "Work"
bevy-tasks sort by-due-date --list "Personal"
```

### Deliverables

- ✅ `bevy-tasks-core` library with stable API
- ✅ Functional CLI that can manage tasks
- ✅ Data persists as Obsidian-compatible .md files
- ✅ Well-tested backend (>80% coverage)
- ✅ Documentation for core library API

### Development Setup

```bash
# Clone and build
git clone <repository-url>
cd bevy-tasks
cargo build

# Run tests
cargo test -p bevy-tasks-core

# Run CLI
cargo run -p bevy-tasks-cli -- init ~/test-tasks
cargo run -p bevy-tasks-cli -- add "Test task"
cargo run -p bevy-tasks-cli -- list
```

---

## Phase 2: WebDAV Sync (Backend + CLI)

**Goal**: Enable cross-device synchronization via CLI

### Architecture

#### WebDAV Integration

Add WebDAV support to `bevy-tasks-core`:

```rust
// Update AppConfig
AppConfig {
    local_path: PathBuf,             // User-selected tasks folder (required)
    webdav_url: Option<String>,
    webdav_credentials: Option<Credentials>,
    last_sync: Option<DateTime>,
    // Note: list_order and last_opened_list in .metadata.json at root of tasks folder
}

// Add sync methods to TaskRepository
impl TaskRepository {
    pub fn sync_push(&mut self) -> Result<SyncResult>;
    pub fn sync_pull(&mut self) -> Result<SyncResult>;
    pub fn sync_status(&self) -> Result<SyncStatus>;
}
```

#### Sync Strategy
- **Trigger**: On app start (if connected), background timer (every 5 min), on modification (debounced)
- **Conflict Resolution**: Last-write-wins with timestamp
- **Offline Support**: Queue operations when offline, sync when online

#### Authentication

**Primary**: Platform Keychain via `keyring` crate
- Store WebDAV username + password in system keychain
- Key format: `com.bevy-tasks.webdav.{server-domain}`
- Works on: Windows (Credential Manager), macOS (Keychain), Linux (Secret Service), iOS/Android (Keystore)

**Fallback**: Encrypted local storage if keychain unavailable

### Dependencies

Add to `bevy-tasks-core/Cargo.toml`:
```toml
reqwest = { version = "0.12", features = ["json", "rustls-tls"] }
keyring = "3.0"
# TODO: Evaluate dav-client or implement custom WebDAV
```

### Features

- [ ] WebDAV client implementation in core library
- [ ] Credential storage (platform keychain)
- [ ] Bi-directional sync (push/pull)
- [ ] Conflict resolution (last-write-wins)
- [ ] Offline queue for pending operations
- [ ] CLI: `sync --setup` command
- [ ] CLI: `sync --push` command
- [ ] CLI: `sync --pull` command
- [ ] CLI: `sync --status` command
- [ ] Progress indicators for sync operations

### CLI Usage Examples

```bash
# Setup WebDAV
bevy-tasks sync --setup
# Prompts for: URL, username, password (stored in keychain)

# Manual sync
bevy-tasks sync --push
bevy-tasks sync --pull

# Check sync status
bevy-tasks sync --status
```

### Deliverables

- ✅ Working WebDAV sync in backend
- ✅ CLI can sync with remote WebDAV server
- ✅ Reliable conflict resolution
- ✅ Tested with Nextcloud, ownCloud

---

## Phase 3: GUI MVP (Desktop)

**Goal**: Build graphical interface on desktop platforms

### Architecture

#### Frontend Framework: egui

**Decision**: Use egui (immediate mode GUI) for MVP

**Why egui?**
- Fast development with rich built-in widgets
- Excellent text editing support out of the box
- Small binary size (~2-3MB stripped)
- Fast startup time (100-200ms target)
- Mature and stable
- Simple immediate-mode API
- Cross-platform (desktop AND mobile)
- Easy integration with `bevy-tasks-core`

#### GUI Crate Structure

```
crates/bevy-tasks-gui/
├── Cargo.toml
├── src/
│   ├── main.rs           # App entry point
│   ├── app.rs            # egui app setup
│   ├── ui/
│   │   ├── mod.rs
│   │   ├── screens/
│   │   │   ├── task_list.rs
│   │   │   ├── task_detail.rs
│   │   │   └── settings.rs
│   │   └── components/
│   │       ├── task_item.rs
│   │       ├── task_input.rs
│   │       └── list_selector.rs
│   └── state.rs          # UI state management
├── assets/
│   ├── fonts/
│   └── icons/
└── README.md
```

#### First Run Experience
- Show folder picker dialog on first launch
- User selects where to store tasks (e.g., `~/Documents/Tasks`)
- No default hidden directories
- Remember choice in app config

#### App Configuration (Phase 3+)

**Update AppConfig** to include UI preferences:
```rust
AppConfig {
    local_path: PathBuf,             // From Phase 1
    webdav_url: Option<String>,      // From Phase 2
    webdav_credentials: Option<Credentials>,
    last_sync: Option<DateTime>,
    theme: Theme,                    // NEW: light/dark mode
    window_size: Option<(u32, u32)>, // NEW: remember window size
    last_opened_list: Option<Uuid>,  // NEW: restore last view
}
```

### Dependencies

**bevy-tasks-gui/Cargo.toml**:
```toml
[package]
name = "bevy-tasks-gui"
version = "0.1.0"
edition = "2024"

[dependencies]
bevy-tasks-core = { path = "../bevy-tasks-core" }
anyhow = { workspace = true }

# egui for Phase 3-6
eframe = "0.31"  # egui framework with native windowing
egui = "0.31"    # Core egui library
```

### Performance Strategy

**Startup Sequence**:
1. Initialize eframe window (< 50ms)
2. Load config from disk (< 20ms)
3. Render empty UI (first frame < 100ms)
4. Load current task list in background
5. Update UI as tasks load
6. Start WebDAV sync in background (if configured)

**Target**: < 200ms cold start on desktop

**Optimizations**:
- Lazy data loading (load visible tasks first)
- Background operations for sync
- Efficient file I/O (stream large files)
- Minimal dependencies

### Features

- [ ] egui framework integration
- [ ] Folder picker dialog on first launch
- [ ] Basic task list view
- [ ] Create new tasks
- [ ] Edit existing tasks
- [ ] Delete tasks
- [ ] Mark tasks complete/incomplete
- [ ] Settings screen (change folder, WebDAV config)
- [ ] Sync status indicators
- [ ] Desktop support (Windows, Linux, macOS)

### Deliverables

- ✅ Functional desktop GUI app
- ✅ Sub-200ms startup time
- ✅ Clean, minimal UI
- ✅ Feature parity with CLI

### Build & Release

**Distribution**:
- Linux: AppImage, .tar.gz
- macOS: DMG
- Windows: MSI, portable .exe

**CI/CD**: GitHub Actions for automated builds

---

## Phase 4: Mobile Basic Support

**Goal**: Get app running on iOS and Android ASAP, validate architecture

### Why Early Mobile?
- De-risk mobile builds early in development
- Test cross-platform architecture sooner
- Validate egui on mobile
- Get mobile-specific feedback early
- Can dogfood on mobile while building desktop features

### Architecture

#### Mobile Build Setup

**iOS**:
- Use Xcode for builds
- Target: `aarch64-apple-ios`
- Bundle identifier: `com.bevy-tasks`

**Android**:
- Use Android SDK/NDK
- Build with `cargo-apk` or `cargo-ndk`
- Min SDK: 26 (Android 8.0)

#### egui Mobile Adaptation

**Touch Support**:
- egui has basic touch support
- Add larger touch targets (44pt minimum)
- Test on real devices

**File System Access**:
- iOS: App sandbox documents directory + file picker
- Android: Scoped storage + SAF (Storage Access Framework)

#### First Run on Mobile
- Show folder picker on first launch
- Suggest locations: Documents, iCloud Drive (iOS), Google Drive (Android)
- User selects folder, path stored in preferences

### Platform-Specific Code

```rust
#[cfg(target_os = "ios")]
mod ios {
    // iOS-specific file picker, etc.
}

#[cfg(target_os = "android")]
mod android {
    // Android-specific file picker, etc.
}
```

### Features

- [ ] iOS build pipeline setup (Xcode project)
- [ ] Android build pipeline setup (Gradle/NDK)
- [ ] Basic egui mobile adaptation
- [ ] Simple test UI (even just buttons for CRUD)
- [ ] File system access on iOS
- [ ] File system access on Android
- [ ] Folder picker for mobile
- [ ] Basic task CRUD on mobile
- [ ] Test on real devices

### Deliverables

- ✅ App launches on iOS
- ✅ App launches on Android
- ✅ Can create and view tasks on mobile
- ✅ Validates cross-platform architecture
- ✅ Foundation for future mobile polish

### Distribution

- iOS: .ipa for TestFlight (early access)
- Android: .apk (direct install / sideloading)

**Note**: This phase prioritizes getting mobile working, even with a simple UI. Polish comes in Phase 6.

---

## Phase 5: GUI Advanced Features (Desktop + Mobile)

**Goal**: Feature parity with Google Tasks across all platforms

### Features

#### Desktop & Mobile
- [ ] Multiple task lists (folders)
- [ ] Switch between lists
- [ ] Subtasks support
- [ ] Due dates with date picker
- [ ] Rich markdown editor for task notes
- [ ] Move tasks between lists
- [ ] Change storage folder location in settings
- [ ] Search functionality
- [ ] Theme selection (light/dark mode)

#### Desktop-Specific
- [ ] Drag & drop reordering
- [ ] Keyboard shortcuts
- [ ] Multiple windows (optional)

#### Mobile-Specific
- [ ] Swipe gestures (swipe to complete, swipe to delete)
- [ ] Pull-to-refresh
- [ ] Touch-optimized UI elements
- [ ] Larger touch targets

### Deliverables

- ✅ Full-featured task manager on all platforms
- ✅ Polished UX on desktop
- ✅ Touch-optimized UX on mobile
- ✅ Consistent feature set across platforms

---

## Phase 6: Mobile Polish & Platform-Specific Features

**Goal**: Native mobile experience and deep platform integration

### Features

#### iOS-Specific
- [ ] Share extension (share to tasks)
- [ ] iOS widgets (home screen, lock screen)
- [ ] Siri shortcuts
- [ ] Haptic feedback
- [ ] iOS-native gestures
- [ ] App icon badge with task count
- [ ] Quick capture via 3D touch / long press
- [ ] iCloud Drive integration

#### Android-Specific
- [ ] Share target (share to tasks)
- [ ] Android widgets (home screen)
- [ ] Quick settings tile
- [ ] Haptic feedback
- [ ] Material Design guidelines
- [ ] Google Drive integration

#### Both Platforms
- [ ] Background sync on mobile
- [ ] Push notifications for due dates
- [ ] Notification actions (complete from notification)
- [ ] App shortcuts
- [ ] Platform-specific animations

### Deliverables

- ✅ Native-feeling mobile apps
- ✅ Deep platform integration
- ✅ Mobile-specific features

### Distribution

**App Store Distribution**:
- iOS: Apple App Store
- Android: Google Play Store
- Android: F-Droid (FOSS store)

---

## Phase 7: Advanced Features & Imports

**Goal**: Differentiate from Google Tasks, add unique features

### Features

#### Google Tasks Importer
- [ ] **Import from Google Tasks** (via API or export)
- [ ] Migrate tasks, lists, due dates, notes
- [ ] Preserve task hierarchy and order
- [ ] Easy onboarding for Google Tasks users

#### Advanced Task Management
- [ ] Recurring tasks (daily, weekly, monthly, custom)
- [ ] Task templates (save common tasks)
- [ ] Bulk operations (select multiple, bulk edit)
- [ ] Full-text search across all tasks
- [ ] Filters and smart lists (e.g., "Due this week")
- [ ] Statistics and insights (completion rate, etc.)

#### Integration & Automation
- [ ] Calendar integration (view tasks in calendar)
- [ ] Email to task (send email to create task)
- [ ] Voice input (speech-to-text for tasks)
- [ ] URL schemes / deep links
- [ ] Zapier integration (optional)

#### Collaboration (Optional)
- [ ] Share lists with other users
- [ ] Collaborative editing
- [ ] Comments on tasks
- [ ] Activity log

#### Customization & Polish
- [ ] Custom themes and color schemes
- [ ] Advanced animations (consider Bevy migration)
- [ ] Plugin system for extensions (optional)
- [ ] Custom fonts
- [ ] Export/import (backup/restore to .zip)

### Optional: Bevy Migration

If you want game-like polish after Phase 7:
- Migrate GUI from egui to Bevy
- Full control over animations and rendering
- Unique, polished look beyond standard apps
- Backend (`bevy-tasks-core`) stays identical
- Only rewrite `bevy-tasks-gui` crate

### Deliverables

- ✅ Polished, delightful UX
- ✅ Unique features not in Google Tasks
- ✅ Easy migration path from Google Tasks
- ✅ Distribution to all app stores

### Final Distribution

**All Platforms**:
- F-Droid (FOSS Android)
- Flathub (Linux Flatpak)
- Google Play Store (Android)
- Apple App Store (iOS and macOS)
- Microsoft Store (Windows)
- Direct downloads (all platforms)

---

## License

[GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.en.html)

This project is free and open-source software licensed under GPL v3.

---

**Last Updated**: 2025-10-27
**Document Version**: 3.0
**Status**: Ready to Implement - Milestone-Driven Plan
