use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use flutter_rust_bridge::frb;
use notify_debouncer_mini::{new_debouncer, DebouncedEventKind};
use once_cell::sync::Lazy;
use uuid::Uuid;

use onyx_core::{
    config::{AppConfig, WorkspaceConfig},
    models::{Task, TaskStatus},
    repository::TaskRepository,
};

// ── State ───────────────────────────────────────────────────────────

struct AppState {
    config: AppConfig,
    repo: Option<TaskRepository>,
}

static STATE: Lazy<Mutex<AppState>> = Lazy::new(|| {
    let config_path = AppConfig::get_config_path();
    let config = AppConfig::load_from_file(&config_path).unwrap_or_default();
    Mutex::new(AppState { config, repo: None })
});

fn ensure_repo(state: &mut AppState) -> Result<(), String> {
    if state.repo.is_some() {
        return Ok(());
    }
    let (_name, ws) = state.config.get_current_workspace().map_err(|e| e.to_string())?;
    let repo = TaskRepository::new(ws.path.clone()).map_err(|e| e.to_string())?;
    state.repo = Some(repo);
    Ok(())
}

// ── DTOs ────────────────────────────────────────────────────────────

pub struct TaskDto {
    pub id: String,
    pub title: String,
    pub description: String,
    pub status: String,
    pub due_date: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub parent_id: Option<String>,
}

pub struct TaskListDto {
    pub id: String,
    pub title: String,
    pub created_at: String,
    pub updated_at: String,
    pub group_by_due_date: bool,
}

pub struct WorkspaceEntry {
    pub name: String,
    pub path: String,
    pub webdav_url: Option<String>,
    pub last_sync: Option<String>,
}

pub struct AppConfigDto {
    pub workspaces: Vec<WorkspaceEntry>,
    pub current_workspace: Option<String>,
}

fn task_to_dto(t: &Task) -> TaskDto {
    TaskDto {
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

fn config_to_dto(c: &AppConfig) -> AppConfigDto {
    AppConfigDto {
        workspaces: c
            .workspaces
            .iter()
            .map(|(name, ws)| WorkspaceEntry {
                name: name.clone(),
                path: ws.path.to_string_lossy().into_owned(),
                webdav_url: ws.webdav_url.clone(),
                last_sync: ws.last_sync.map(|d| d.to_rfc3339()),
            })
            .collect(),
        current_workspace: c.current_workspace.clone(),
    }
}

// ── Config commands ─────────────────────────────────────────────────

pub fn get_config() -> Result<AppConfigDto, String> {
    let s = STATE.lock().unwrap();
    Ok(config_to_dto(&s.config))
}

pub fn init_workspace(path: String) -> Result<(), String> {
    TaskRepository::init(PathBuf::from(path))
        .map(|_| ())
        .map_err(|e| e.to_string())
}

pub fn add_workspace(name: String, path: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    let ws = WorkspaceConfig::new(PathBuf::from(&path));
    s.config.add_workspace(name.clone(), ws);
    s.config.set_current_workspace(name).map_err(|e| e.to_string())?;
    s.repo = None;
    let config_path = AppConfig::get_config_path();
    s.config.save_to_file(&config_path).map_err(|e| e.to_string())
}

pub fn set_current_workspace(name: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    s.config.set_current_workspace(name).map_err(|e| e.to_string())?;
    s.repo = None;
    let config_path = AppConfig::get_config_path();
    s.config.save_to_file(&config_path).map_err(|e| e.to_string())
}

pub fn remove_workspace(name: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    s.config.remove_workspace(&name);
    s.repo = None;
    let config_path = AppConfig::get_config_path();
    s.config.save_to_file(&config_path).map_err(|e| e.to_string())
}

// ── List commands ───────────────────────────────────────────────────

pub fn get_lists() -> Result<Vec<TaskListDto>, String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    let lists = s.repo.as_ref().unwrap().get_lists().map_err(|e| e.to_string())?;
    Ok(lists
        .iter()
        .map(|l| TaskListDto {
            id: l.id.to_string(),
            title: l.title.clone(),
            created_at: l.created_at.to_rfc3339(),
            updated_at: l.updated_at.to_rfc3339(),
            group_by_due_date: l.group_by_due_date,
        })
        .collect())
}

pub fn create_list(name: String) -> Result<TaskListDto, String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let list = s.repo.as_mut().unwrap().create_list(name).map_err(|e| e.to_string())?;
    Ok(TaskListDto {
        id: list.id.to_string(),
        title: list.title.clone(),
        created_at: list.created_at.to_rfc3339(),
        updated_at: list.updated_at.to_rfc3339(),
        group_by_due_date: list.group_by_due_date,
    })
}

pub fn delete_list(list_id: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo.as_mut().unwrap().delete_list(id).map_err(|e| e.to_string())
}

// ── Task commands ───────────────────────────────────────────────────

pub fn list_tasks(list_id: String) -> Result<Vec<TaskDto>, String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tasks = s.repo.as_ref().unwrap().list_tasks(id).map_err(|e| e.to_string())?;
    Ok(tasks.iter().map(|t| task_to_dto(t)).collect())
}

pub fn create_task(list_id: String, title: String, description: String) -> Result<TaskDto, String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let mut task = Task::new(title);
    if !description.is_empty() {
        task.description = description;
    }
    let created = s.repo.as_mut().unwrap().create_task(id, task).map_err(|e| e.to_string())?;
    Ok(task_to_dto(&created))
}

pub fn update_task(list_id: String, task: TaskDto) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task.id).map_err(|e| e.to_string())?;

    let mut existing = s.repo.as_ref().unwrap().get_task(lid, tid).map_err(|e| e.to_string())?;
    existing.title = task.title;
    existing.description = task.description;
    existing.due_date = task
        .due_date
        .as_deref()
        .and_then(|d| chrono::DateTime::parse_from_rfc3339(d).ok())
        .map(|d| d.with_timezone(&chrono::Utc));

    s.repo.as_mut().unwrap().update_task(lid, existing).map_err(|e| e.to_string())
}

pub fn delete_task(list_id: String, task_id: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo.as_mut().unwrap().delete_task(lid, tid).map_err(|e| e.to_string())
}

pub fn toggle_task(list_id: String, task_id: String) -> Result<TaskDto, String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    let repo = s.repo.as_mut().unwrap();
    let mut task = repo.get_task(lid, tid).map_err(|e| e.to_string())?;
    match task.status {
        TaskStatus::Backlog => task.complete(),
        TaskStatus::Completed => task.uncomplete(),
    }
    repo.update_task(lid, task.clone()).map_err(|e| e.to_string())?;
    Ok(task_to_dto(&task))
}

pub fn reorder_task(list_id: String, task_id: String, new_position: u32) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let lid = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo
        .as_mut()
        .unwrap()
        .reorder_task(lid, tid, new_position as usize)
        .map_err(|e| e.to_string())
}

// ── Move / rename / grouping ───────────────────────────────────────

pub fn move_task(from_list_id: String, to_list_id: String, task_id: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let from = Uuid::parse_str(&from_list_id).map_err(|e| e.to_string())?;
    let to = Uuid::parse_str(&to_list_id).map_err(|e| e.to_string())?;
    let tid = Uuid::parse_str(&task_id).map_err(|e| e.to_string())?;
    s.repo.as_mut().unwrap().move_task(from, to, tid).map_err(|e| e.to_string())
}

pub fn rename_list(list_id: String, new_name: String) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo.as_mut().unwrap().rename_list(id, new_name).map_err(|e| e.to_string())
}

pub fn set_group_by_due_date(list_id: String, enabled: bool) -> Result<(), String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    mute_watcher();
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo.as_mut().unwrap().set_group_by_due_date(id, enabled).map_err(|e| e.to_string())
}

pub fn get_group_by_due_date(list_id: String) -> Result<bool, String> {
    let mut s = STATE.lock().unwrap();
    ensure_repo(&mut s)?;
    let id = Uuid::parse_str(&list_id).map_err(|e| e.to_string())?;
    s.repo.as_ref().unwrap().get_group_by_due_date(id).map_err(|e| e.to_string())
}

// ── File watcher ───────────────────────────────────────────────────

static WATCHER: Mutex<Option<notify_debouncer_mini::Debouncer<notify::RecommendedWatcher>>> =
    Mutex::new(None);

static LAST_WRITE: Mutex<Option<Instant>> = Mutex::new(None);

fn mute_watcher() {
    *LAST_WRITE.lock().unwrap() = Some(Instant::now());
}

#[frb(stream_dart_await)]
pub fn watch_workspace_changes(path: String, sink: crate::frb_generated::StreamSink<()>) {
    let debouncer = new_debouncer(
        Duration::from_millis(500),
        move |events: Result<Vec<notify_debouncer_mini::DebouncedEvent>, notify::Error>| {
            let Ok(events) = events else { return };
            let has_data_change = events.iter().any(|e| {
                if e.kind != DebouncedEventKind::Any { return false; }
                let p = e.path.to_string_lossy();
                p.ends_with(".md") || p.ends_with(".json")
            });
            if !has_data_change { return; }
            if let Some(t) = *LAST_WRITE.lock().unwrap() {
                if t.elapsed() < Duration::from_secs(1) { return; }
            }
            let _ = sink.add(());
        },
    );
    match debouncer {
        Ok(mut d) => {
            let _ = d.watcher().watch(&PathBuf::from(&path), notify::RecursiveMode::Recursive);
            *WATCHER.lock().unwrap() = Some(d);
        }
        Err(e) => eprintln!("Failed to start file watcher: {e}"),
    }
}

// ── Test function ───────────────────────────────────────────────────

pub fn greet(name: String) -> String {
    format!("Hello, {name}! From Rust via flutter_rust_bridge.")
}
