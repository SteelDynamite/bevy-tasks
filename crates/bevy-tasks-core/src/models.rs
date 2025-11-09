use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Task status enum
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TaskStatus {
    /// Task not yet completed
    Backlog,
    /// Task is done
    Completed,
}

/// A single task
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub title: String,
    pub description: String,
    pub status: TaskStatus,
    pub due_date: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub parent_id: Option<Uuid>,
}

impl Task {
    /// Create a new task with the given title
    pub fn new(title: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            title,
            description: String::new(),
            status: TaskStatus::Backlog,
            due_date: None,
            created_at: now,
            updated_at: now,
            parent_id: None,
        }
    }

    /// Mark task as completed
    pub fn complete(&mut self) {
        self.status = TaskStatus::Completed;
        self.updated_at = Utc::now();
    }

    /// Mark task as backlog (incomplete)
    pub fn uncomplete(&mut self) {
        self.status = TaskStatus::Backlog;
        self.updated_at = Utc::now();
    }
}

/// Metadata for a task list stored in .listdata.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListMetadata {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub group_by_due_date: bool,
    pub task_order: Vec<Uuid>,
}

impl ListMetadata {
    pub fn new(id: Uuid) -> Self {
        let now = Utc::now();
        Self {
            id,
            created_at: now,
            updated_at: now,
            group_by_due_date: false,
            task_order: Vec::new(),
        }
    }
}

/// A task list (represented by a folder on disk)
#[derive(Debug, Clone)]
pub struct TaskList {
    pub id: Uuid,
    pub title: String,
    pub tasks: Vec<Task>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub group_by_due_date: bool,
}

impl TaskList {
    /// Create a new task list
    pub fn new(title: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            title,
            tasks: Vec::new(),
            created_at: now,
            updated_at: now,
            group_by_due_date: false,
        }
    }
}

/// Global metadata stored in .metadata.json at the workspace root
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GlobalMetadata {
    pub version: u32,
    pub list_order: Vec<Uuid>,
    pub last_opened_list: Option<Uuid>,
}

impl Default for GlobalMetadata {
    fn default() -> Self {
        Self {
            version: 1,
            list_order: Vec::new(),
            last_opened_list: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_task_creation() {
        let task = Task::new("Test task".to_string());
        assert_eq!(task.title, "Test task");
        assert_eq!(task.status, TaskStatus::Backlog);
        assert_eq!(task.description, "");
    }

    #[test]
    fn test_task_complete() {
        let mut task = Task::new("Test task".to_string());
        task.complete();
        assert_eq!(task.status, TaskStatus::Completed);
    }

    #[test]
    fn test_task_uncomplete() {
        let mut task = Task::new("Test task".to_string());
        task.complete();
        task.uncomplete();
        assert_eq!(task.status, TaskStatus::Backlog);
    }
}
