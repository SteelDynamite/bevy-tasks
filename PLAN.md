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

### Core Framework
- **Bevy 0.16+**: Game engine providing cross-platform rendering and ECS architecture
- **bevy_ui**: For immediate UI components
- **bevy_egui**: Optional for more complex UI widgets (if needed)

### Data Storage Layer
- **serde**: Serialization/deserialization
- **pulldown-cmark** or **markdown**: Markdown parsing
- **gray_matter** or **yaml-rust**: YAML frontmatter parsing (Obsidian-style metadata)
- **directories**: Cross-platform path handling
- **tokio**: Async runtime for I/O operations
- **reqwest** + **dav-client**: WebDAV support

### Mobile Platform Support
- **bevy_mobile_example**: Reference for iOS/Android builds
- **cargo-apk**: Android builds
- **xcode**: iOS builds

### Performance Optimization
- **Lazy loading**: Load only visible data
- **Asset preprocessing**: Minimize runtime overhead
- **Minimal dependencies**: Keep binary size small
- **Release optimizations**: LTO, strip symbols

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

### Module Structure

```
bevy-tasks/
├── src/
│   ├── main.rs              # Entry point
│   ├── app.rs               # Bevy app setup
│   ├── data/
│   │   ├── mod.rs
│   │   ├── models.rs        # Task, TaskList, AppConfig
│   │   ├── repository.rs    # Data access abstraction
│   │   └── storage/
│   │       ├── mod.rs
│   │       ├── local.rs     # Local file storage
│   │       └── webdav.rs    # WebDAV client
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
│   ├── systems/
│   │   ├── mod.rs
│   │   ├── input.rs         # Input handling
│   │   ├── sync.rs          # Background sync
│   │   └── navigation.rs    # Screen navigation
│   └── resources/
│       ├── mod.rs
│       └── app_state.rs     # Global state management
├── assets/
│   ├── fonts/
│   └── icons/
├── Cargo.toml
└── PLAN.md
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

### Phase 1: MVP
**Goal**: Basic local-first tasks app on desktop platforms

**Features**:
- [ ] Single task list
- [ ] Create, read, update, delete tasks
- [ ] Mark tasks as complete/incomplete
- [ ] Local file storage (Markdown files)
- [ ] Markdown parsing with YAML frontmatter
- [ ] Basic UI (list view)
- [ ] Desktop support (Windows, Linux, macOS)

**Deliverables**:
- Functional desktop app
- Data persists across sessions as .md files
- Sub-second startup time

### Phase 2: Multiple Lists & Organization
**Goal**: Feature parity with basic Google Tasks functionality

**Features**:
- [ ] Multiple task lists (folders)
- [ ] Switch between lists
- [ ] Subtasks support (nested folders or parent_id)
- [ ] Due dates (frontmatter metadata)
- [ ] Task notes/descriptions (markdown content)
- [ ] Reorder tasks (drag & drop, updates position)
- [ ] Move tasks between lists (move .md files)
- [ ] Folder picker for custom storage location

**Deliverables**:
- Full task management functionality
- Improved UI/UX
- Obsidian-compatible file format

### Phase 3: WebDAV Sync
**Goal**: Enable cross-device synchronization

**Features**:
- [ ] WebDAV client implementation
- [ ] Settings screen for storage configuration
- [ ] Credential storage (see Authentication section)
- [ ] Sync status indicators
- [ ] Conflict resolution (last-write-wins with manual review option)
- [ ] Offline mode with queue
- [ ] Manual sync trigger
- [ ] Bi-directional sync of .md files

**Deliverables**:
- Working WebDAV sync
- Reliable conflict resolution
- Seamless offline/online transitions

### Phase 4: Mobile Support
**Goal**: Deploy to iOS and Android

**Features**:
- [ ] Touch-optimized UI
- [ ] iOS build pipeline
- [ ] Android build pipeline
- [ ] Mobile-specific UX (swipe gestures, pull-to-refresh)
- [ ] Background sync on mobile
- [ ] Mobile file system integration
- [ ] Share extension (share to tasks)

**Deliverables**:
- Working iOS app
- Working Android app
- Consistent UX across mobile and desktop

### Phase 5: Polish & Advanced Features
**Goal**: Differentiate from Google Tasks, leverage Bevy's capabilities

**Features**:
- [ ] Themes and customization
- [ ] Advanced animations and transitions
- [ ] Keyboard shortcuts
- [ ] Full-text search across tasks
- [ ] Filters and smart lists
- [ ] Task templates
- [ ] Recurring tasks
- [ ] Statistics and insights
- [ ] Game-like achievement system (optional)
- [ ] Custom UI skins
- [ ] Plugin system for extensions

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

## Dependencies

### Core Dependencies
```toml
[dependencies]
bevy = "0.16"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_yaml = "0.9"  # For frontmatter parsing
pulldown-cmark = "0.9"  # Markdown parsing
uuid = { version = "1.0", features = ["serde", "v4"] }
chrono = { version = "0.4", features = ["serde"] }
directories = "5.0"
tokio = { version = "1.0", features = ["full"] }
anyhow = "1.0"

# WebDAV support
reqwest = { version = "0.11", features = ["json"] }
# Note: Evaluate dav-client alternatives

# Credential storage (see Authentication Options)
keyring = "2.0"  # Cross-platform keychain access

# Platform-specific
[target.'cfg(target_os = "android")'.dependencies]
# Android-specific deps

[target.'cfg(target_os = "ios")'.dependencies]
# iOS-specific deps
```

## Getting Started

### Prerequisites
- Rust 1.75+ (Bevy 0.16 requirement)
- Platform-specific tools:
  - **iOS**: macOS + Xcode
  - **Android**: Android SDK + NDK

### Development Setup
```bash
# Clone repository
git clone <repository-url>
cd bevy-tasks

# Run desktop version
cargo run

# Build for release
cargo build --release

# Run tests
cargo test

# Build for Android
cargo apk build --release

# Build for iOS (on macOS)
cargo build --target aarch64-apple-ios --release
```

## Questions & Decisions

### 1. UI Framework: bevy_ui vs bevy_egui

#### Option A: Pure bevy_ui
**Pros**:
- Native to Bevy, no additional dependencies
- Full control over rendering and styling
- Better performance (no intermediate UI layer)
- Fits Bevy's ECS paradigm perfectly
- More flexibility for game-like UX polish later
- Smaller binary size
- Consistent cross-platform look

**Cons**:
- More verbose, lower-level API
- Need to build complex widgets from scratch
- Text input handling requires more work
- Fewer built-in widgets
- Steeper learning curve for complex layouts
- More code to maintain

**Best for**: If you want maximum performance, full control, and are willing to invest time building custom widgets.

#### Option B: bevy_egui
**Pros**:
- Rich set of built-in widgets (text input, combo boxes, etc.)
- Immediate mode GUI is simple to reason about
- Rapid prototyping and iteration
- Good text editing support out of the box
- Mature ecosystem
- Less code for standard UI patterns
- Better accessibility features

**Cons**:
- Additional dependency (~500KB+)
- Slight performance overhead
- Less control over rendering
- Immediate mode pattern conflicts with ECS
- Harder to achieve game-like polish
- Less Bevy-native feel
- More challenging to customize appearance

**Best for**: If you want to ship quickly with standard UI widgets and don't need deep customization.

#### Option C: Hybrid Approach
Use **bevy_ui** for primary interface (task lists, main views) and **bevy_egui** for complex forms and settings screens.

**Pros**:
- Best of both worlds
- Use right tool for each job
- Fast development where needed, optimized where it matters

**Cons**:
- Two UI systems to learn and maintain
- Increased binary size
- Inconsistent look without careful styling

#### Recommendation
Start with **pure bevy_ui** for MVP. The task list UI is relatively simple (lists, buttons, text), and this gives you:
- Maximum performance for fast startup
- Foundation for future game-like polish
- Full control over mobile UX

Reserve bevy_egui as a fallback if text editing becomes too complex to implement.

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

**Last Updated**: 2025-10-26
**Document Version**: 1.1
**Status**: Planning Phase
