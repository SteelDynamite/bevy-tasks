use std::path::PathBuf;
use std::sync::Mutex;

use bevy_tasks_core::{
    config::{AppConfig, WorkspaceConfig},
    models::{Task, TaskList, TaskStatus},
    repository::TaskRepository,
    sync::{self, SyncMode, SyncResult as CoreSyncResult},
    webdav,
};

// ── Bridge types ─────────────────────────────────────────────────────

/// Flat task struct for FFI transport.
pub struct BridgeTask {
    pub id: String,
    pub title: String,
    pub description: String,
    pub status: String,
    pub due_date: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub parent_id: Option<String>,
}

/// Flat list struct for FFI transport.
pub struct BridgeTaskList {
    pub id: String,
    pub title: String,
    pub created_at: String,
    pub updated_at: String,
    pub group_by_due_date: bool,
}

/// Flat workspace config for FFI transport.
pub struct BridgeWorkspace {
    pub name: String,
    pub path: String,
    pub webdav_url: Option<String>,
    pub last_sync: Option<String>,
}

/// Flat app config for FFI transport.
pub struct BridgeConfig {
    pub workspaces: Vec<BridgeWorkspace>,
    pub current_workspace: Option<String>,
}

/// Sync result for FFI transport.
pub struct BridgeSyncResult {
    pub uploaded: u32,
    pub downloaded: u32,
    pub deleted_local: u32,
    pub deleted_remote: u32,
    pub conflicts: u32,
    pub errors: Vec<String>,
}

// ── Conversion helpers ───────────────────────────────────────────────

fn task_to_bridge(t: &Task) -> BridgeTask {
    BridgeTask {
        id: t.id.to_string(),
        title: t.title.clone(),
        description: t.description.clone(),
        status: match t.status {
            TaskStatus::Backlog => "backlog".into(),
            TaskStatus::Completed => "completed".into(),
        },
        due_date: t.due_date.map(|d| d.to_rfc3339()),
        created_at: t.created_at.to_rfc3339(),
        updated_at: t.updated_at.to_rfc3339(),
        parent_id: t.parent_id.map(|id| id.to_string()),
    }
}

fn list_to_bridge(l: &TaskList) -> BridgeTaskList {
    BridgeTaskList {
        id: l.id.to_string(),
        title: l.title.clone(),
        created_at: l.created_at.to_rfc3339(),
        updated_at: l.updated_at.to_rfc3339(),
        group_by_due_date: l.group_by_due_date,
    }
}

fn config_to_bridge(c: &AppConfig) -> BridgeConfig {
    BridgeConfig {
        workspaces: c
            .workspaces
            .iter()
            .map(|(name, ws)| BridgeWorkspace {
                name: name.clone(),
                path: ws.path.to_string_lossy().into_owned(),
                webdav_url: ws.webdav_url.clone(),
                last_sync: ws.last_sync.map(|d| d.to_rfc3339()),
            })
            .collect(),
        current_workspace: c.current_workspace.clone(),
    }
}

// ── Global state ─────────────────────────────────────────────────────

static STATE: Mutex<Option<AppState>> = Mutex::new(None);

struct AppState {
    config: AppConfig,
    repo: Option<TaskRepository>,
}

fn with_state<T>(f: impl FnOnce(&mut AppState) -> Result<T, String>) -> Result<T, String> {
    let mut guard = STATE.lock().map_err(|e| e.to_string())?;
    let state = guard.as_mut().ok_or("App not initialized")?;
    f(state)
}

fn ensure_repo(state: &mut AppState) -> Result<(), String> {
    if state.repo.is_some() {
        return Ok(());
    }
    let (_name, ws) = state.config.get_current_workspace().map_err(|e| e.to_string())?;
    let repo = TaskRepository::new(ws.path.clone()).map_err(|e| e.to_string())?;
    state.repo = Some(repo);
    Ok(())
}

// ── Public API (flutter_rust_bridge will generate Dart bindings) ─────

/// Initialize the bridge. Must be called once at app startup.
pub fn init_app() -> Result<BridgeConfig, String> {
    let config_path = AppConfig::get_config_path();
    let config = AppConfig::load_from_file(&config_path).unwrap_or_default();
    let bridge_config = config_to_bridge(&config);
    let mut guard = STATE.lock().map_err(|e| e.to_string())?;
    *guard = Some(AppState { config, repo: None });
    Ok(bridge_config)
}

pub fn get_config() -> Result<BridgeConfig, String> {
    with_state(|s| Ok(config_to_bridge(&s.config)))
}

pub fn add_workspace(name: String, path: String) -> Result<(), String> {
    // Init workspace on disk
    TaskRepository::init(PathBuf::from(&path))
        .map(|_| ())
        .map_err(|e| e.to_string())?;

    with_state(|s| {
        let ws = WorkspaceConfig::new(PathBuf::from(&path));
        s.config.add_workspace(name.clone(), ws);
        s.config.set_current_workspace(name).map_err(|e| e.to_string())?;
        s.repo = None;
        let config_path = AppConfig::get_config_path();
        s.config.save_to_file(&config_path).map_err(|e| e.to_string())
    })
}

pub fn set_current_workspace(name: String) -> Result<(), String> {
    with_state(|s| {
        s.config.set_current_workspace(name).map_err(|e| e.to_string())?;
        s.repo = None;
        let config_path = AppConfig::get_config_path();
        s.config.save_to_file(&config_path).map_err(|e| e.to_string())
    })
}

pub fn remove_workspace(name: String) -> Result<(), String> {
    with_state(|s| {
        s.config.remove_workspace(&name);
        s.repo = None;
        let config_path = AppConfig::get_config_path();
        s.config.save_to_file(&config_path).map_err(|e| e.to_string())
    })
}

pub fn get_lists() -> Result<Vec<BridgeTaskList>, String> {
    with_state(|s| {
        ensure_repo(s)?;
        s.repo
            .as_ref()
            .unwrap()
            .get_lists()
            .map(|lists| lists.iter().map(|l| list_to_bridge(l)).collect())
            .map_err(|e| e.to_string())
    })
}

pub fn create_list(name: String) -> Result<BridgeTaskList, String> {
    with_state(|s| {
        ensure_repo(s)?;
        s.repo
            .as_mut()
            .unwrap()
            .create_list(name)
            .map(|l| list_to_bridge(&l))
            .map_err(|e| e.to_string())
    })
}

pub fn delete_list(list_id: String) -> Result<(), String> {
    with_state(|s| {
        ensure_repo(s)?;
        let id = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        s.repo.as_mut().unwrap().delete_list(id).map_err(|e| e.to_string())
    })
}

pub fn list_tasks(list_id: String) -> Result<Vec<BridgeTask>, String> {
    with_state(|s| {
        ensure_repo(s)?;
        let id = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        s.repo
            .as_ref()
            .unwrap()
            .list_tasks(id)
            .map(|tasks| tasks.iter().map(|t| task_to_bridge(t)).collect())
            .map_err(|e| e.to_string())
    })
}

pub fn create_task(list_id: String, title: String) -> Result<BridgeTask, String> {
    with_state(|s| {
        ensure_repo(s)?;
        let id = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        let task = Task::new(title);
        s.repo
            .as_mut()
            .unwrap()
            .create_task(id, task)
            .map(|t| task_to_bridge(&t))
            .map_err(|e| e.to_string())
    })
}

pub fn toggle_task(list_id: String, task_id: String) -> Result<BridgeTask, String> {
    with_state(|s| {
        ensure_repo(s)?;
        let lid = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        let tid = uuid::Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
        let repo = s.repo.as_mut().unwrap();
        let mut task = repo.get_task(lid, tid).map_err(|e| e.to_string())?;
        match task.status {
            TaskStatus::Backlog => task.complete(),
            TaskStatus::Completed => task.uncomplete(),
        }
        repo.update_task(lid, task.clone()).map_err(|e| e.to_string())?;
        Ok(task_to_bridge(&task))
    })
}

pub fn update_task(list_id: String, task_id: String, title: String, description: String) -> Result<(), String> {
    with_state(|s| {
        ensure_repo(s)?;
        let lid = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        let tid = uuid::Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
        let repo = s.repo.as_mut().unwrap();
        let mut task = repo.get_task(lid, tid).map_err(|e| e.to_string())?;
        task.title = title;
        task.description = description;
        repo.update_task(lid, task).map_err(|e| e.to_string())
    })
}

pub fn delete_task(list_id: String, task_id: String) -> Result<(), String> {
    with_state(|s| {
        ensure_repo(s)?;
        let lid = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        let tid = uuid::Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
        s.repo.as_mut().unwrap().delete_task(lid, tid).map_err(|e| e.to_string())
    })
}

pub fn reorder_task(list_id: String, task_id: String, new_position: usize) -> Result<(), String> {
    with_state(|s| {
        ensure_repo(s)?;
        let lid = uuid::Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
        let tid = uuid::Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
        s.repo.as_mut().unwrap().reorder_task(lid, tid, new_position).map_err(|e| e.to_string())
    })
}

pub fn set_webdav_config(workspace_name: String, webdav_url: String) -> Result<(), String> {
    with_state(|s| {
        if let Some(ws) = s.config.workspaces.get_mut(&workspace_name) {
            ws.webdav_url = Some(webdav_url);
        }
        let config_path = AppConfig::get_config_path();
        s.config.save_to_file(&config_path).map_err(|e| e.to_string())
    })
}

pub fn store_webdav_credentials(domain: String, username: String, password: String) -> Result<(), String> {
    webdav::store_credentials(&domain, &username, &password).map_err(|e| e.to_string())
}

pub async fn sync_workspace_bridge(
    workspace_path: String,
    webdav_url: String,
    username: String,
    password: String,
) -> Result<BridgeSyncResult, String> {
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

    Ok(BridgeSyncResult {
        uploaded: result.uploaded,
        downloaded: result.downloaded,
        deleted_local: result.deleted_local,
        deleted_remote: result.deleted_remote,
        conflicts: result.conflicts,
        errors: result.errors,
    })
}
