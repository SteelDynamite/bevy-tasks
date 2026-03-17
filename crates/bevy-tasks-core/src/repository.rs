use std::path::PathBuf;
use uuid::Uuid;
use crate::error::{Error, Result};
use crate::models::{Task, TaskList};
use crate::storage::{FileSystemStorage, Storage};

pub struct TaskRepository {
    storage: Box<dyn Storage>,
}

impl TaskRepository {
    pub fn new(tasks_folder: PathBuf) -> Result<Self> {
        let storage = FileSystemStorage::new(tasks_folder)?;
        Ok(Self {
            storage: Box::new(storage),
        })
    }

    pub fn init(tasks_folder: PathBuf) -> Result<Self> {
        let storage = FileSystemStorage::init(tasks_folder)?;
        Ok(Self {
            storage: Box::new(storage),
        })
    }

    // Task operations
    pub fn create_task(&mut self, list_id: Uuid, task: Task) -> Result<Task> {
        self.storage.write_task(list_id, &task)?;
        Ok(task)
    }

    pub fn get_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task> {
        self.storage.read_task(list_id, task_id)
    }

    pub fn update_task(&mut self, list_id: Uuid, task: Task) -> Result<()> {
        // Verify task exists first
        let _ = self.storage.read_task(list_id, task.id)?;
        self.storage.write_task(list_id, &task)?;
        Ok(())
    }

    pub fn delete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()> {
        self.storage.delete_task(list_id, task_id)
    }

    pub fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>> {
        self.storage.list_tasks(list_id)
    }

    // List operations
    pub fn create_list(&mut self, name: String) -> Result<TaskList> {
        self.storage.create_list(name)
    }

    pub fn get_lists(&self) -> Result<Vec<TaskList>> {
        self.storage.get_lists()
    }

    pub fn get_list(&self, list_id: Uuid) -> Result<TaskList> {
        let lists = self.get_lists()?;
        lists.into_iter()
            .find(|list| list.id == list_id)
            .ok_or_else(|| Error::ListNotFound(list_id.to_string()))
    }

    pub fn delete_list(&mut self, list_id: Uuid) -> Result<()> {
        self.storage.delete_list(list_id)
    }

    // Task ordering
    pub fn reorder_task(&mut self, list_id: Uuid, task_id: Uuid, new_position: usize) -> Result<()> {
        let mut metadata = self.storage.read_list_metadata(list_id)?;

        // Find current position
        let current_pos = metadata.task_order.iter().position(|&id| id == task_id)
            .ok_or_else(|| Error::TaskNotFound(task_id.to_string()))?;

        // Remove from current position
        metadata.task_order.remove(current_pos);

        // Insert at new position
        let new_pos = new_position.min(metadata.task_order.len());
        metadata.task_order.insert(new_pos, task_id);

        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;

        Ok(())
    }

    pub fn get_task_order(&self, list_id: Uuid) -> Result<Vec<Uuid>> {
        let metadata = self.storage.read_list_metadata(list_id)?;
        Ok(metadata.task_order)
    }

    // Grouping preference
    pub fn set_group_by_due_date(&mut self, list_id: Uuid, enabled: bool) -> Result<()> {
        let mut metadata = self.storage.read_list_metadata(list_id)?;
        metadata.group_by_due_date = enabled;
        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;
        Ok(())
    }

    pub fn get_group_by_due_date(&self, list_id: Uuid) -> Result<bool> {
        let metadata = self.storage.read_list_metadata(list_id)?;
        Ok(metadata.group_by_due_date)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_init_repository() {
        let temp_dir = TempDir::new().unwrap();
        let repo = TaskRepository::init(temp_dir.path().to_path_buf());
        assert!(repo.is_ok());
    }

    #[test]
    fn test_create_and_list_tasks() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        // Create a list
        let list = repo.create_list("Test List".to_string()).unwrap();

        // Create a task
        let task = Task::new("Test Task".to_string());
        let created_task = repo.create_task(list.id, task).unwrap();

        // List tasks
        let tasks = repo.list_tasks(list.id).unwrap();
        assert_eq!(tasks.len(), 1);
        assert_eq!(tasks[0].title, "Test Task");
    }

    #[test]
    fn test_update_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let list = repo.create_list("Test List".to_string()).unwrap();
        let mut task = Task::new("Original".to_string());
        task = repo.create_task(list.id, task).unwrap();

        task.title = "Updated".to_string();
        repo.update_task(list.id, task.clone()).unwrap();

        let retrieved = repo.get_task(list.id, task.id).unwrap();
        assert_eq!(retrieved.title, "Updated");
    }

    #[test]
    fn test_delete_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let list = repo.create_list("Test List".to_string()).unwrap();
        let task = Task::new("To Delete".to_string());
        let task = repo.create_task(list.id, task).unwrap();

        repo.delete_task(list.id, task.id).unwrap();

        let tasks = repo.list_tasks(list.id).unwrap();
        assert_eq!(tasks.len(), 0);
    }

    #[test]
    fn test_reorder_tasks() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let list = repo.create_list("Test List".to_string()).unwrap();

        let task1 = repo.create_task(list.id, Task::new("Task 1".to_string())).unwrap();
        let task2 = repo.create_task(list.id, Task::new("Task 2".to_string())).unwrap();
        let task3 = repo.create_task(list.id, Task::new("Task 3".to_string())).unwrap();

        // Move task3 to position 0
        repo.reorder_task(list.id, task3.id, 0).unwrap();

        let order = repo.get_task_order(list.id).unwrap();
        assert_eq!(order[0], task3.id);
        assert_eq!(order[1], task1.id);
        assert_eq!(order[2], task2.id);
    }

    #[test]
    fn test_group_by_due_date() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let list = repo.create_list("Test List".to_string()).unwrap();

        assert!(!repo.get_group_by_due_date(list.id).unwrap());

        repo.set_group_by_due_date(list.id, true).unwrap();
        assert!(repo.get_group_by_due_date(list.id).unwrap());

        repo.set_group_by_due_date(list.id, false).unwrap();
        assert!(!repo.get_group_by_due_date(list.id).unwrap());
    }
}
