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
    storage_type: StorageType,  // Local or WebDAV
    local_path: Option<PathBuf>,
    webdav_url: Option<String>,
    webdav_credentials: Option<Credentials>,
    theme: Theme,
    last_sync: Option<DateTime>,
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
    pub fn new(config: Config) -> Result<Self>;
    pub fn init(path: PathBuf) -> Result<Self>;

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
- **Location**: User-selectable folder OR platform-specific app data directory
  - Windows: `%APPDATA%/bevy-tasks/` (default)
  - Linux: `~/.local/share/bevy-tasks/` (default)
  - macOS: `~/Library/Application Support/bevy-tasks/` (default)
  - iOS: App sandbox documents directory
  - Android: Internal storage app directory
  - User can select any folder with read/write permissions
- **Format**: Markdown files with YAML frontmatter (Obsidian-compatible)
- **Structure**:
  ```
  data/
  ├── .bevy-tasks/
  │   ├── config.json          # App configuration
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

**Benefits of Markdown Format**:
- Human-readable and editable in any text editor
- Compatible with Obsidian, Logseq, and other markdown tools
- Easy to version control (git-friendly)
- Future-proof format
- Enables external editing and scripting
- Natural organization with folders

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
2. **Lazy UI rendering**: Render visible items first
3. **Background loading**: Load non-critical data after first frame
4. **Asset optimization**: Embed minimal assets, load rest async
5. **Incremental parsing**: Stream large data files

#### Startup Sequence
1. Initialize Bevy minimal plugins (< 50ms)
2. Load config from disk (< 20ms)
3. Render splash/empty state (first frame < 100ms)
4. Load task lists in background
5. Render tasks as they load
6. Start WebDAV sync (if configured)

#### Memory Optimization
- Use `Vec` instead of `HashMap` for small collections
- Limit rendered tasks to visible viewport
- Unload non-visible screens from memory

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
bevy-tasks init ~/my-tasks
bevy-tasks add "Buy groceries" --list "Personal"
bevy-tasks list
bevy-tasks complete <task-id>
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
- [ ] Settings screen (storage location, WebDAV config)
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
- [ ] Folder picker for custom storage
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

### Challenge 1: Fast Startup with Bevy
**Problem**: Bevy's plugin system can add overhead

**Solutions**:
- Use `MinimalPlugins` instead of `DefaultPlugins`
- Add only required plugins (rendering, input)
- Lazy-load audio, asset server if not needed immediately
- Profile startup and optimize hot paths

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

## Frontend Framework Comparison

Now that we have backend/frontend separation, we can evaluate multiple GUI framework options. The backend (`bevy-tasks-core`) is framework-agnostic.

### Option 1: Bevy (Game Engine)
**Language**: Rust
**Architecture**: ECS (Entity Component System)

**Pros**:
- ✅ True cross-platform (Windows, Linux, macOS, iOS, Android, WASM)
- ✅ Excellent performance (60+ FPS easily)
- ✅ Future game-like polish and animations
- ✅ Active community and development
- ✅ Full control over rendering
- ✅ Single codebase for all platforms
- ✅ Fast startup possible with `MinimalPlugins`

**Cons**:
- ❌ UI system is still maturing (bevy_ui improving but limited)
- ❌ More code required for standard widgets
- ❌ Steeper learning curve (ECS paradigm)
- ❌ Larger binary size (~5-10MB stripped)
- ❌ Text input handling requires extra work
- ❌ Not designed for traditional UIs

**Best for**: If you want game-like polish, animations, and are willing to build custom UI components.

**Startup time estimate**: 200-500ms
**Binary size**: 5-10MB (stripped)

---

### Option 2: egui (Immediate Mode GUI)
**Language**: Rust
**Integration**: Standalone or with eframe

**Pros**:
- ✅ True cross-platform (desktop, WASM, can run on mobile)
- ✅ Very simple API (immediate mode)
- ✅ Rich built-in widgets
- ✅ Excellent text editing support
- ✅ Small binary size (~2-3MB)
- ✅ Fast development iteration
- ✅ Mature and stable
- ✅ Good performance
- ✅ Works with multiple backends (glow, wgpu)

**Cons**:
- ❌ Mobile support exists but less mature
- ❌ Immediate mode can be unusual coming from retained mode
- ❌ Less flexibility for custom animations
- ❌ Harder to achieve "game-like" polish
- ❌ Less native feel on each platform

**Best for**: Quick development, standard UI needs, if you don't need game-like features.

**Startup time estimate**: 100-200ms
**Binary size**: 2-3MB (stripped)

---

### Option 3: Iced (Elm-inspired)
**Language**: Rust
**Architecture**: The Elm Architecture (TEA)

**Pros**:
- ✅ Cross-platform (Windows, Linux, macOS, WASM)
- ✅ Declarative, reactive UI (similar to SwiftUI/Flutter)
- ✅ Clean architecture with clear state management
- ✅ Type-safe
- ✅ Good widget library
- ✅ Native-feeling widgets
- ✅ Async support built-in
- ✅ Medium binary size (~3-5MB)

**Cons**:
- ❌ Mobile support experimental (iOS/Android not production-ready)
- ❌ Smaller community than egui or Bevy
- ❌ Still evolving (breaking changes possible)
- ❌ Limited animation capabilities
- ❌ Less documentation than mature frameworks

**Best for**: If you like reactive/declarative UIs and primarily target desktop + WASM.

**Startup time estimate**: 150-300ms
**Binary size**: 3-5MB (stripped)

---

### Option 4: Dioxus (React-like)
**Language**: Rust
**Architecture**: Virtual DOM with React-like hooks

**Pros**:
- ✅ Cross-platform (desktop, web, mobile via TUI or webview)
- ✅ React-like API (familiar to web devs)
- ✅ Hot reload support
- ✅ Component-based architecture
- ✅ Fast development
- ✅ Can target web with same code
- ✅ Active development

**Cons**:
- ❌ Mobile support uses webview (not truly native)
- ❌ Still young and evolving
- ❌ Less mature than other options
- ❌ Performance not as good as native solutions
- ❌ Webview adds overhead on mobile

**Best for**: Web developers wanting familiar patterns, prioritizing web deployment.

**Startup time estimate**: 200-400ms (desktop), slower on mobile (webview)
**Binary size**: 4-8MB (includes webview on mobile)

---

### Option 5: Tauri (Web Tech + Rust Backend)
**Language**: HTML/CSS/JavaScript (or any web framework) + Rust
**Architecture**: Webview with Rust backend

**Pros**:
- ✅ Use any web framework (React, Vue, Svelte, etc.)
- ✅ Rapid UI development with web technologies
- ✅ Small binary size (uses system webview)
- ✅ Desktop support excellent (Windows, Linux, macOS)
- ✅ Mobile support coming (Tauri Mobile)
- ✅ Large ecosystem of web UI libraries
- ✅ Familiar to web developers
- ✅ Hot reload support

**Cons**:
- ❌ Depends on system webview (consistency issues)
- ❌ Mobile support still in beta
- ❌ Not truly native look/feel
- ❌ Performance worse than native solutions
- ❌ Startup time slower (webview initialization)
- ❌ Requires web dev skills
- ❌ More complex build process

**Best for**: Teams with web dev experience, if you want to use React/Vue/Svelte.

**Startup time estimate**: 300-800ms (webview initialization)
**Binary size**: 1-3MB (uses system webview)

---

### Option 6: Slint (Declarative UI)
**Language**: Slint language + Rust
**Architecture**: Declarative markup language

**Pros**:
- ✅ True cross-platform (desktop, embedded, mobile coming)
- ✅ Declarative UI with .slint files
- ✅ Native rendering (no webview)
- ✅ Good performance
- ✅ Design tools available
- ✅ Small binary size
- ✅ Good documentation
- ✅ Business-backed (SixtyFPS GmbH)

**Cons**:
- ❌ Mobile support experimental
- ❌ Smaller community
- ❌ Need to learn new markup language
- ❌ Less flexible than code-based solutions
- ❌ Dual licensing (GPL or commercial)

**Best for**: If you want declarative UI with good tooling and don't mind learning new syntax.

**Startup time estimate**: 100-250ms
**Binary size**: 2-4MB

---

### Option 7: Flutter (Dart)
**Language**: Dart (not Rust!)
**Architecture**: Widget tree

**Pros**:
- ✅ Best mobile support (iOS, Android)
- ✅ Very mature and stable
- ✅ Huge widget library
- ✅ Excellent documentation
- ✅ Great tooling and dev experience
- ✅ Desktop support good
- ✅ Beautiful UIs out of the box
- ✅ Fast startup on mobile

**Cons**:
- ❌ **Not Rust!** (breaks our stack)
- ❌ Requires Dart FFI to call Rust backend
- ❌ Larger binary size (10-20MB)
- ❌ Different language/ecosystem
- ❌ More complex integration

**Best for**: If mobile is top priority and you're willing to use Dart + Rust FFI.

**Startup time estimate**: 200-400ms
**Binary size**: 10-20MB

---

### Option 8: Native Platform UIs (Platform-specific)
**Language**: Rust + platform bindings
**Options**: gtk-rs (Linux), windows-rs (Windows), cacao (macOS), UIKit bindings (iOS), Android NDK

**Pros**:
- ✅ True native look and feel per platform
- ✅ Best platform integration
- ✅ Smallest binaries per platform
- ✅ Fastest startup time
- ✅ Platform features "just work"

**Cons**:
- ❌ **Separate codebase per platform**
- ❌ 5x development effort
- ❌ Hard to maintain consistency
- ❌ Need to learn each platform
- ❌ More testing required

**Best for**: If native feel is paramount and you have resources for multiple codebases.

**Startup time estimate**: 50-150ms (native)
**Binary size**: 1-3MB per platform

---

## Frontend Framework Recommendation

Based on your requirements (fast startup, cross-platform, potential for game-like polish):

### Recommended: Start with **egui** for Phase 3

**Why egui?**
1. **Fastest time to market**: Rich widgets out of the box
2. **Good performance**: Fast startup, low overhead
3. **Cross-platform**: Desktop works great, mobile possible
4. **Simple integration**: Easy to connect to `bevy-tasks-core`
5. **Validate UX**: Test core app experience quickly
6. **Path forward**: Can always switch to Bevy later if you want game-like features

### Alternative path: **Bevy** for unique polish

**Choose Bevy if:**
- You want game-like animations from the start
- You're excited about building custom UI
- You value long-term flexibility over short-term speed
- You want a unique, polished look

### Hybrid approach (Recommended)

**Best of both worlds:**
1. Build Phase 3 MVP with **egui** (fast iteration)
2. Validate UX, backend API, and app concept
3. If you want more polish, rebuild with **Bevy** in Phase 6
4. Backend stays the same (clean separation!)

This de-risks the project while keeping options open.

### Quick Decision Matrix

| Framework | Startup | Binary | Mobile | Dev Speed | Polish Potential | Learning Curve |
|-----------|---------|--------|--------|-----------|-----------------|----------------|
| **Bevy**      | ⚠️ Medium | ⚠️ Large | ✅ Good | ⚠️ Slow | ⭐⭐⭐⭐⭐ | Hard |
| **egui**      | ✅ Fast | ✅ Small | ⚠️ OK | ✅ Fast | ⭐⭐⭐ | Easy |
| **Iced**      | ✅ Fast | ✅ Small | ❌ Poor | ✅ Good | ⭐⭐⭐ | Medium |
| **Dioxus**    | ⚠️ Medium | ⚠️ Medium | ⚠️ Webview | ✅ Fast | ⭐⭐ | Easy (if React) |
| **Tauri**     | ❌ Slow | ✅ Small | ⚠️ Beta | ✅ Very Fast | ⭐⭐ | Easy (web) |
| **Slint**     | ✅ Fast | ✅ Small | ⚠️ Exp | ⚠️ Medium | ⭐⭐⭐ | Medium |
| **Flutter**   | ✅ Fast | ⚠️ Large | ⭐⭐⭐⭐⭐ | ✅ Very Fast | ⭐⭐⭐⭐ | Medium (Dart) |
| **Native**    | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ Very Slow | ⭐⭐⭐⭐ | Very Hard |

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

# GUI framework - TBD based on chosen option
# Option 1: Bevy
# bevy = { version = "0.16", default-features = false, features = ["bevy_ui", "bevy_render", "bevy_winit"] }

# Option 2: egui (Recommended for MVP)
# eframe = "0.31"
# egui = "0.31"

# Option 3: Iced
# iced = { version = "0.13", features = ["tokio"] }

# Option 4: Dioxus
# dioxus = "0.6"
# dioxus-desktop = "0.6"

# Platform-specific
[target.'cfg(target_os = "android")'.dependencies]
# Android-specific deps

[target.'cfg(target_os = "ios")'.dependencies]
# iOS-specific deps
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
cargo run -- init ~/my-tasks
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

### 1. Frontend Framework Choice

**Status**: See "Frontend Framework Comparison" section above for detailed analysis.

**Current Recommendation**: Start with **egui** for Phase 3 (fast MVP), optionally migrate to **Bevy** in Phase 6 for polish.

---

### 2. Authentication Options for WebDAV

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
**Document Version**: 2.0
**Status**: Planning Phase - Backend/Frontend Separation Decided
