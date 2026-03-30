use std::path::PathBuf;
use std::sync::Mutex;

use serde::{Deserialize, Serialize};
use tauri::State;
use uuid::Uuid;

use bevy_tasks_core::{
    config::{AppConfig, WorkspaceConfig},
    models::{Task, TaskList, TaskStatus},
    repository::TaskRepository,
    sync::{self, SyncMode, SyncResult as CoreSyncResult},
    webdav,
};

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
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .reorder_task(lid, tid, new_position)
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
async fn test_webdav_connection(
    url: String,
    username: String,
    password: String,
) -> Result<(), String> {
    let client = bevy_tasks_core::webdav::WebDavClient::new(&url, &username, &password);
    client
        .test_connection()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
async fn sync_workspace(
    workspace_path: String,
    webdav_url: String,
    username: String,
    password: String,
) -> Result<SyncResult, String> {
    let result = sync::sync_workspace(
        &PathBuf::from(workspace_path),
        &webdav_url,
        &username,
        &password,
        SyncMode::Full,
        None,
    )
    .await
    .map_err(|e| e.to_string())?;
    Ok(result.into())
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
            set_webdav_config,
            store_credentials,
            test_webdav_connection,
            sync_workspace,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
