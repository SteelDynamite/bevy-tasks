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
- **serde_json** or **rmp-serde**: JSON or MessagePack for task data
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

```
Task {
    id: Uuid,
    title: String,
    notes: Option<String>,
    status: TaskStatus,  // NotStarted, InProgress, Completed
    due_date: Option<DateTime>,
    created_at: DateTime,
    updated_at: DateTime,
    parent_id: Option<Uuid>,  // For subtasks
    position: i32,  // For ordering
}

TaskList {
    id: Uuid,
    title: String,
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
- **Location**: Platform-specific app data directory
  - Windows: `%APPDATA%/bevy-tasks/`
  - Linux: `~/.local/share/bevy-tasks/`
  - macOS: `~/Library/Application Support/bevy-tasks/`
  - iOS: App sandbox documents directory
  - Android: Internal storage app directory
- **Format**: JSON files (human-readable, debuggable)
- **Structure**:
  ```
  data/
  ├── config.json
  ├── lists/
  │   ├── {list-id-1}.json
  │   └── {list-id-2}.json
  └── metadata.json
  ```

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

### Phase 1: MVP (Weeks 1-4)
**Goal**: Basic local-first tasks app on desktop platforms

**Features**:
- [ ] Single task list
- [ ] Create, read, update, delete tasks
- [ ] Mark tasks as complete/incomplete
- [ ] Local file storage (JSON)
- [ ] Basic UI (list view)
- [ ] Desktop support (Windows, Linux, macOS)

**Deliverables**:
- Functional desktop app
- Data persists across sessions
- Sub-second startup time

### Phase 2: Multiple Lists & Organization (Weeks 5-6)
**Goal**: Feature parity with basic Google Tasks functionality

**Features**:
- [ ] Multiple task lists
- [ ] Switch between lists
- [ ] Subtasks support
- [ ] Due dates
- [ ] Task notes/descriptions
- [ ] Reorder tasks (drag & drop)
- [ ] Move tasks between lists

**Deliverables**:
- Full task management functionality
- Improved UI/UX

### Phase 3: WebDAV Sync (Weeks 7-9)
**Goal**: Enable cross-device synchronization

**Features**:
- [ ] WebDAV client implementation
- [ ] Settings screen for storage configuration
- [ ] Sync status indicators
- [ ] Conflict resolution
- [ ] Offline mode with queue
- [ ] Manual sync trigger

**Deliverables**:
- Working WebDAV sync
- Reliable conflict resolution
- Seamless offline/online transitions

### Phase 4: Mobile Support (Weeks 10-14)
**Goal**: Deploy to iOS and Android

**Features**:
- [ ] Touch-optimized UI
- [ ] iOS build pipeline
- [ ] Android build pipeline
- [ ] Mobile-specific UX (swipe gestures, etc.)
- [ ] Background sync on mobile
- [ ] Push notifications (optional)

**Deliverables**:
- Working iOS app
- Working Android app
- Consistent UX across mobile and desktop

### Phase 5: Polish & Advanced Features (Weeks 15+)
**Goal**: Differentiate from Google Tasks, leverage Bevy's capabilities

**Features**:
- [ ] Themes and customization
- [ ] Advanced animations
- [ ] Keyboard shortcuts
- [ ] Search and filters
- [ ] Task templates
- [ ] Recurring tasks
- [ ] Statistics and insights
- [ ] Game-like achievement system (optional)
- [ ] Custom UI skins

**Deliverables**:
- Polished, delightful UX
- Unique features not in Google Tasks

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
- **Desktop**: Direct downloads (AppImage, DMG, MSI)
- **Mobile**: App Store and Google Play
- **Version scheme**: Semantic versioning (0.1.0 → 1.0.0)

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
- Cache credentials securely (use platform keychains)
- Queue operations when offline
- Provide clear sync status to user
- Support multiple WebDAV servers (Nextcloud, ownCloud, etc.)

### Challenge 4: Data Migration
**Problem**: Schema changes need to preserve user data

**Solutions**:
- Version data format from day one
- Write migration scripts for each version bump
- Test migrations with real user data
- Backup before migration

## Success Metrics

### Performance
- ✓ Startup time < 500ms on mid-range devices
- ✓ 60 FPS UI on all platforms
- ✓ Handle 10,000+ tasks without performance degradation

### User Experience
- ✓ Task creation in < 3 taps/clicks
- ✓ Zero data loss
- ✓ Sync conflicts rare and auto-resolved

### Platform Support
- ✓ All 5 platforms working
- ✓ Consistent feature set across platforms
- ✓ Native feel on each platform

## Dependencies

### Core Dependencies
```toml
[dependencies]
bevy = "0.16"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
uuid = { version = "1.0", features = ["serde", "v4"] }
chrono = { version = "0.4", features = ["serde"] }
directories = "5.0"
tokio = { version = "1.0", features = ["full"] }
anyhow = "1.0"

# WebDAV support
reqwest = { version = "0.11", features = ["json"] }
# Note: Evaluate dav-client alternatives

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

## Questions & Decisions Needed

1. **UI Framework**: Pure bevy_ui or bevy_egui for complex widgets?
2. **Data Format**: JSON (human-readable) or MessagePack (efficient)?
3. **Authentication**: How to securely store WebDAV credentials?
4. **Distribution**: Self-hosted only or aim for app stores?
5. **Backup Strategy**: Automatic local backups? Export functionality?

## Resources

- [Bevy Documentation](https://bevyengine.org/)
- [Bevy Mobile Examples](https://github.com/bevyengine/bevy/tree/main/examples/mobile)
- [WebDAV RFC 4918](https://datatracker.ietf.org/doc/html/rfc4918)
- [Google Tasks API](https://developers.google.com/tasks) (for feature reference)

## License

To be determined.

---

**Last Updated**: 2025-10-26
**Document Version**: 1.0
**Status**: Planning Phase
