use std::path::PathBuf;
use std::sync::Mutex;
use std::time::Instant;

use chrono::Utc;

#[cfg(not(target_os = "android"))]
use notify_debouncer_mini::{new_debouncer, DebouncedEventKind};
use serde::{Deserialize, Serialize};
use tauri::{Emitter, Manager, State};
use uuid::Uuid;

use onyx_core::{
    config::{AppConfig, WorkspaceConfig},
    models::{Task, TaskList, TaskStatus},
    repository::TaskRepository,
    sync::{self, SyncMode, SyncResult as CoreSyncResult},
    webdav,
};

#[cfg(not(target_os = "android"))]
/// Active file watcher stored globally so it lives for the app lifetime.
static WATCHER: Mutex<Option<notify_debouncer_mini::Debouncer<notify::RecommendedWatcher>>> =
    Mutex::new(None);

#[cfg(not(target_os = "android"))]
/// Shared mute timestamp — set before writes, checked by the watcher.
static LAST_WRITE: Mutex<Option<Instant>> = Mutex::new(None);

/// Shared application state behind a mutex.
struct AppState {
    config: AppConfig,
    repo: Option<TaskRepository>,
}

/// Serializable sync result for the frontend.
#[derive(Debug, Serialize, Deserialize, Clone)]
struct SyncResult {
    uploaded: u32,
    downloaded: u32,
    deleted_local: u32,
    deleted_remote: u32,
    conflicts: u32,
    errors: Vec<String>,
}

impl From<CoreSyncResult> for SyncResult {
    fn from(r: CoreSyncResult) -> Self {
        Self {
            uploaded: r.uploaded,
            downloaded: r.downloaded,
            deleted_local: r.deleted_local,
            deleted_remote: r.deleted_remote,
            conflicts: r.conflicts,
            errors: r.errors,
        }
    }
}

/// Suppress file watcher events for the next second (call before writes).
#[cfg(not(target_os = "android"))]
fn mute_watcher(_state: &mut AppState) {
    *LAST_WRITE.lock().unwrap() = Some(Instant::now());
}

#[cfg(target_os = "android")]
fn mute_watcher(_state: &mut AppState) {}

/// Helper: get or open a TaskRepository for the current workspace.
fn ensure_repo(state: &mut AppState) -> Result<(), String> {
    if state.repo.is_some() {
        return Ok(());
    }
    let (_name, ws) = state
        .config
        .get_current_workspace()
        .map_err(|e| e.to_string())?;
    let repo = TaskRepository::new(ws.path.clone()).map_err(|e| e.to_string())?;
    state.repo = Some(repo);
    Ok(())
}

// ── Config commands ──────────────────────────────────────────────────

#[tauri::command]
fn get_config(state: State<'_, Mutex<AppState>>) -> Result<AppConfig, String> {
    let s = state.lock().unwrap();
    Ok(s.config.clone())
}

#[tauri::command]
fn save_config(state: State<'_, Mutex<AppState>>) -> Result<(), String> {
    let s = state.lock().unwrap();
    let path = AppConfig::get_config_path();
    s.config.save_to_file(&path).map_err(|e| e.to_string())
}

#[tauri::command]
fn add_workspace(
    name: String,
    path: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    let ws = WorkspaceConfig::new(PathBuf::from(&path));
    s.config.add_workspace(name.clone(), ws);
    s.config
        .set_current_workspace(name)
        .map_err(|e| e.to_string())?;
    // Reset repo so it reopens on next access
    s.repo = None;
    let config_path = AppConfig::get_config_path();
    s.config
        .save_to_file(&config_path)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn set_current_workspace(
    name: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    s.config
        .set_current_workspace(name)
        .map_err(|e| e.to_string())?;
    s.repo = None;
    let config_path = AppConfig::get_config_path();
    s.config
        .save_to_file(&config_path)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn remove_workspace(
    name: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    s.config.remove_workspace(&name);
    s.repo = None;
    let config_path = AppConfig::get_config_path();
    s.config
        .save_to_file(&config_path)
        .map_err(|e| e.to_string())
}

// ── Workspace init ───────────────────────────────────────────────────

#[tauri::command]
fn init_workspace(path: String) -> Result<(), String> {
    TaskRepository::init(PathBuf::from(path))
        .map(|_| ())
        .map_err(|e| e.to_string())
}

// ── List commands ────────────────────────────────────────────────────

#[tauri::command]
fn get_lists(state: State<'_, Mutex<AppState>>) -> Result<Vec<TaskList>, String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    s.repo
        .as_ref()
        .unwrap()
        .get_lists()
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn create_list(
    name: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<TaskList, String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    s.repo
        .as_mut()
        .unwrap()
        .create_list(name)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn delete_list(
    list_id: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .delete_list(id)
        .map_err(|e| e.to_string())
}

// ── Task commands ────────────────────────────────────────────────────

#[tauri::command]
fn list_tasks(
    list_id: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<Vec<Task>, String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo
        .as_ref()
        .unwrap()
        .list_tasks(id)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn create_task(
    list_id: String,
    title: String,
    description: Option<String>,
    state: State<'_, Mutex<AppState>>,
) -> Result<Task, String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let mut task = Task::new(title);
    if let Some(desc) = description.filter(|d| !d.is_empty()) {
        task.description = desc;
    }
    s.repo
        .as_mut()
        .unwrap()
        .create_task(id, task)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn update_task(
    list_id: String,
    task: Task,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .update_task(id, task)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn delete_task(
    list_id: String,
    task_id: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .delete_task(lid, tid)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn toggle_task(
    list_id: String,
    task_id: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<Task, String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    let repo = s.repo.as_mut().unwrap();
    let mut task = repo.get_task(lid, tid).map_err(|e| e.to_string())?;
    match task.status {
        TaskStatus::Backlog => task.complete(),
        TaskStatus::Completed => task.uncomplete(),
    }
    repo.update_task(lid, task.clone())
        .map_err(|e| e.to_string())?;
    Ok(task)
}

#[tauri::command]
fn reorder_task(
    list_id: String,
    task_id: String,
    new_position: usize,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .reorder_task(lid, tid, new_position)
        .map_err(|e| e.to_string())
}

// ── Move / rename / grouping ────────────────────────────────────────

#[tauri::command]
fn move_task(
    from_list_id: String,
    to_list_id: String,
    task_id: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let from = Uuid::parse_str(&from_list_id).map_err(|e| e.to_string())?;
    let to = Uuid::parse_str(&to_list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .move_task(from, to, tid)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn rename_list(
    list_id: String,
    new_name: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .rename_list(id, new_name)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn set_group_by_due_date(
    list_id: String,
    enabled: bool,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher(&mut s);
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .set_group_by_due_date(id, enabled)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn get_group_by_due_date(
    list_id: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<bool, String> {
    let mut s = state.lock().unwrap();
    ensure_repo(&mut s)?;
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo
        .as_ref()
        .unwrap()
        .get_group_by_due_date(id)
        .map_err(|e| e.to_string())
}

// ── Sync commands ────────────────────────────────────────────────────

#[tauri::command]
fn set_webdav_config(
    workspace_name: String,
    webdav_url: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<(), String> {
    let mut s = state.lock().unwrap();
    if let Some(ws) = s.config.workspaces.get_mut(&workspace_name) {
        ws.webdav_url = Some(webdav_url);
    }
    let config_path = AppConfig::get_config_path();
    s.config
        .save_to_file(&config_path)
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn store_credentials(
    domain: String,
    username: String,
    password: String,
) -> Result<(), String> {
    webdav::store_credentials(&domain, &username, &password).map_err(|e| e.to_string())
}

#[tauri::command]
fn load_credentials(domain: String) -> Result<(String, String), String> {
    webdav::load_credentials(&domain).map_err(|e| e.to_string())
}

#[tauri::command]
async fn test_webdav_connection(
    url: String,
    username: String,
    password: String,
) -> Result<(), String> {
    let client = onyx_core::webdav::WebDavClient::new(&url, &username, &password);
    client
        .test_connection()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
async fn sync_workspace(
    workspace_name: String,
    workspace_path: String,
    webdav_url: String,
    username: String,
    password: String,
    mode: String,
    state: State<'_, Mutex<AppState>>,
) -> Result<SyncResult, String> {
    let sync_mode = match mode.as_str() {
        "push" => SyncMode::Push,
        "pull" => SyncMode::Pull,
        _ => SyncMode::Full,
    };
    let result = sync::sync_workspace(
        &PathBuf::from(&workspace_path),
        &webdav_url,
        &username,
        &password,
        sync_mode,
        None,
    )
    .await
    .map_err(|e| e.to_string())?;

    // Persist last_sync timestamp to config
    {
        let mut s = state.lock().unwrap();
        if let Some(ws) = s.config.workspaces.get_mut(&workspace_name) {
            ws.last_sync = Some(Utc::now());
        }
        let config_path = AppConfig::get_config_path();
        s.config.save_to_file(&config_path).map_err(|e| e.to_string())?;
    }

    Ok(result.into())
}

// ── File watcher ────────────────────────────────────────────────────

#[cfg(not(target_os = "android"))]
fn start_watcher(handle: tauri::AppHandle, path: PathBuf) {
    let handle = handle.clone();
    let debouncer = new_debouncer(
        std::time::Duration::from_millis(500),
        move |events: Result<Vec<notify_debouncer_mini::DebouncedEvent>, notify::Error>| {
            let Ok(events) = events else { return };
            // Only care about data file changes
            let has_data_change = events.iter().any(|e| {
                if e.kind != DebouncedEventKind::Any { return false; }
                let p = e.path.to_string_lossy();
                p.ends_with(".md") || p.ends_with(".json")
            });
            if !has_data_change { return; }
            // Skip if we wrote recently (self-change suppression)
            if let Some(t) = *LAST_WRITE.lock().unwrap() {
                if t.elapsed() < std::time::Duration::from_secs(1) { return; }
            }
            let _ = handle.emit("fs-changed", ());
        },
    );
    match debouncer {
        Ok(mut d) => {
            let _ = d.watcher().watch(&path, notify::RecursiveMode::Recursive);
            *WATCHER.lock().unwrap() = Some(d);
        }
        Err(e) => eprintln!("Failed to start file watcher: {e}"),
    }
}

#[cfg(not(target_os = "android"))]
#[tauri::command]
fn watch_workspace(path: String, app_handle: tauri::AppHandle) -> Result<(), String> {
    start_watcher(app_handle, PathBuf::from(path));
    Ok(())
}

#[cfg(target_os = "android")]
#[tauri::command]
fn watch_workspace(_path: String, _app_handle: tauri::AppHandle) -> Result<(), String> {
    Ok(())
}

// ── App entry ────────────────────────────────────────────────────────

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Load or create config
    let config_path = AppConfig::get_config_path();
    let config = AppConfig::load_from_file(&config_path).unwrap_or_default();

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_os::init())
        .manage(Mutex::new(AppState { config, repo: None }))
        .setup(|app| {
            let handle = app.handle().clone();
            let state: State<'_, Mutex<AppState>> = app.state();
            let workspace_path = {
                let s = state.lock().unwrap();
                s.config.get_current_workspace().ok().map(|(_, ws)| ws.path.clone())
            };
            #[cfg(not(target_os = "android"))]
            if let Some(path) = workspace_path {
                start_watcher(handle, path);
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_config,
            save_config,
            add_workspace,
            set_current_workspace,
            remove_workspace,
            init_workspace,
            get_lists,
            create_list,
            delete_list,
            list_tasks,
            create_task,
            update_task,
            delete_task,
            toggle_task,
            reorder_task,
            move_task,
            rename_list,
            set_group_by_due_date,
            get_group_by_due_date,
            set_webdav_config,
            store_credentials,
            load_credentials,
            test_webdav_connection,
            sync_workspace,
            watch_workspace,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
