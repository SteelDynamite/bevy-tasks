use crate::error::{Error, Result};
use crate::models::{Task, TaskList};
use crate::storage::{FileSystemStorage, Storage};
use crate::sync::{SyncEngine, SyncResult, SyncStatus};
use crate::webdav::WebDavClient;
use std::path::PathBuf;
use uuid::Uuid;

/// Repository for managing tasks and lists
pub struct TaskRepository {
    storage: Box<dyn Storage>,
    workspace_path: PathBuf,
}

impl TaskRepository {
    /// Create a new repository with an existing tasks folder
    pub fn new(tasks_folder: PathBuf) -> Result<Self> {
        let storage = FileSystemStorage::new(tasks_folder.clone())?;
        Ok(Self {
            storage: Box::new(storage),
            workspace_path: tasks_folder,
        })
    }

    /// Initialize a new tasks folder and repository
    pub fn init(tasks_folder: PathBuf) -> Result<Self> {
        let mut storage = FileSystemStorage::new(tasks_folder.clone())?;
        storage.init()?;

        // Create default list
        let _list_id = storage.create_list("My Tasks")?;

        Ok(Self {
            storage: Box::new(storage),
            workspace_path: tasks_folder,
        })
    }

    // Task operations

    /// Create a new task
    pub fn create_task(&mut self, list_id: Uuid, task: Task) -> Result<Task> {
        // Update task order in list metadata
        let mut metadata = self.storage.read_list_metadata(list_id)?;
        metadata.task_order.push(task.id);
        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;

        // Write task to storage
        self.storage.write_task(list_id, &task)?;

        Ok(task)
    }

    /// Get a task by ID
    pub fn get_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task> {
        self.storage.read_task(list_id, task_id)
    }

    /// Update an existing task
    pub fn update_task(&mut self, list_id: Uuid, mut task: Task) -> Result<()> {
        task.updated_at = chrono::Utc::now();
        self.storage.write_task(list_id, &task)?;

        // Update list metadata timestamp
        let mut metadata = self.storage.read_list_metadata(list_id)?;
        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;

        Ok(())
    }

    /// Delete a task
    pub fn delete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()> {
        self.storage.delete_task(list_id, task_id)?;

        // Remove from task order
        let mut metadata = self.storage.read_list_metadata(list_id)?;
        metadata.task_order.retain(|&id| id != task_id);
        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;

        Ok(())
    }

    /// List all tasks in a list, ordered according to task_order
    pub fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>> {
        let tasks = self.storage.list_tasks(list_id)?;
        let metadata = self.storage.read_list_metadata(list_id)?;

        // Create a map for quick lookup
        let task_map: std::collections::HashMap<Uuid, Task> =
            tasks.into_iter().map(|t| (t.id, t)).collect();

        // Order tasks according to task_order
        let mut ordered_tasks = Vec::new();
        for task_id in &metadata.task_order {
            if let Some(task) = task_map.get(task_id) {
                ordered_tasks.push(task.clone());
            }
        }

        // Add any tasks not in task_order at the end
        for (task_id, task) in task_map {
            if !metadata.task_order.contains(&task_id) {
                ordered_tasks.push(task);
            }
        }

        Ok(ordered_tasks)
    }

    /// Complete a task
    pub fn complete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()> {
        let mut task = self.storage.read_task(list_id, task_id)?;
        task.complete();
        self.update_task(list_id, task)?;
        Ok(())
    }

    /// Mark a task as incomplete
    pub fn uncomplete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()> {
        let mut task = self.storage.read_task(list_id, task_id)?;
        task.uncomplete();
        self.update_task(list_id, task)?;
        Ok(())
    }

    // List operations

    /// Create a new task list
    pub fn create_list(&mut self, name: String) -> Result<TaskList> {
        let list_id = self.storage.create_list(&name)?;
        let metadata = self.storage.read_list_metadata(list_id)?;
        Ok(TaskList {
            id: list_id,
            title: name,
            tasks: Vec::new(),
            created_at: metadata.created_at,
            updated_at: metadata.updated_at,
            group_by_due_date: metadata.group_by_due_date,
            archived: metadata.archived,
        })
    }

    /// Get all task lists
    pub fn get_lists(&self) -> Result<Vec<TaskList>> {
        let lists = self.storage.list_lists()?;
        let global_metadata = self.storage.read_global_metadata()?;

        let mut result = Vec::new();
        for (list_id, title) in lists {
            let tasks = self.list_tasks(list_id)?;
            let metadata = self.storage.read_list_metadata(list_id)?;

            result.push(TaskList {
                id: list_id,
                title,
                tasks,
                created_at: metadata.created_at,
                updated_at: metadata.updated_at,
                group_by_due_date: metadata.group_by_due_date,
                archived: metadata.archived,
            });
        }

        // Sort by global list_order
        result.sort_by_key(|list| {
            global_metadata
                .list_order
                .iter()
                .position(|&id| id == list.id)
                .unwrap_or(usize::MAX)
        });

        Ok(result)
    }

    /// Get a specific task list by ID
    pub fn get_list(&self, list_id: Uuid) -> Result<TaskList> {
        let lists = self.storage.list_lists()?;
        let (_, title) = lists
            .into_iter()
            .find(|(id, _)| *id == list_id)
            .ok_or(Error::ListNotFound(list_id))?;

        let tasks = self.list_tasks(list_id)?;
        let metadata = self.storage.read_list_metadata(list_id)?;

        Ok(TaskList {
            id: list_id,
            title,
            tasks,
            created_at: metadata.created_at,
            updated_at: metadata.updated_at,
            group_by_due_date: metadata.group_by_due_date,
            archived: metadata.archived,
        })
    }

    /// Delete a task list
    pub fn delete_list(&mut self, list_id: Uuid) -> Result<()> {
        self.storage.delete_list(list_id)
    }

    /// Rename a task list
    pub fn rename_list(&mut self, list_id: Uuid, new_name: String) -> Result<()> {
        self.storage.rename_list(list_id, new_name)
    }

    /// Archive or unarchive a task list
    pub fn archive_list(&mut self, list_id: Uuid, archived: bool) -> Result<()> {
        self.storage.archive_list(list_id, archived)
    }

    /// Reorder a task list in the global list order
    pub fn reorder_list(&mut self, list_id: Uuid, new_position: usize) -> Result<()> {
        let mut global_metadata = self.storage.read_global_metadata()?;

        // Remove list from current position
        global_metadata.list_order.retain(|&id| id != list_id);

        // Insert at new position
        let insert_pos = new_position.min(global_metadata.list_order.len());
        global_metadata.list_order.insert(insert_pos, list_id);

        self.storage.write_global_metadata(&global_metadata)?;

        Ok(())
    }

    // Task ordering operations

    /// Reorder a task within its list
    pub fn reorder_task(&mut self, list_id: Uuid, task_id: Uuid, new_position: usize) -> Result<()> {
        let mut metadata = self.storage.read_list_metadata(list_id)?;

        // Remove task from current position
        metadata.task_order.retain(|&id| id != task_id);

        // Insert at new position
        let insert_pos = new_position.min(metadata.task_order.len());
        metadata.task_order.insert(insert_pos, task_id);

        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;

        Ok(())
    }

    /// Get the task order for a list
    pub fn get_task_order(&self, list_id: Uuid) -> Result<Vec<Uuid>> {
        let metadata = self.storage.read_list_metadata(list_id)?;
        Ok(metadata.task_order.clone())
    }

    // Grouping operations

    /// Set whether to group tasks by due date
    pub fn set_group_by_due_date(&mut self, list_id: Uuid, enabled: bool) -> Result<()> {
        let mut metadata = self.storage.read_list_metadata(list_id)?;
        metadata.group_by_due_date = enabled;
        metadata.updated_at = chrono::Utc::now();
        self.storage.write_list_metadata(&metadata)?;
        Ok(())
    }

    /// Get whether tasks are grouped by due date
    pub fn get_group_by_due_date(&self, list_id: Uuid) -> Result<bool> {
        let metadata = self.storage.read_list_metadata(list_id)?;
        Ok(metadata.group_by_due_date)
    }

    /// Find a task by ID across all lists
    pub fn find_task(&self, task_id: Uuid) -> Result<(Uuid, Task)> {
        let lists = self.storage.list_lists()?;

        for (list_id, _) in lists {
            if let Ok(task) = self.storage.read_task(list_id, task_id) {
                return Ok((list_id, task));
            }
        }

        Err(Error::TaskNotFound(task_id))
    }

    /// Find a list by name
    pub fn find_list_by_name(&self, name: &str) -> Result<Uuid> {
        let lists = self.storage.list_lists()?;

        for (list_id, list_name) in lists {
            if list_name == name {
                return Ok(list_id);
            }
        }

        Err(Error::Other(format!("List not found: {}", name)))
    }

    // Sync operations

    /// Push local changes to WebDAV server
    ///
    /// # Arguments
    /// * `webdav_client` - Configured WebDAV client for the workspace
    pub async fn sync_push(&self, webdav_client: WebDavClient) -> Result<SyncResult> {
        let engine = SyncEngine::new(self.workspace_path.clone(), webdav_client);
        engine.push().await
    }

    /// Pull remote changes from WebDAV server
    ///
    /// # Arguments
    /// * `webdav_client` - Configured WebDAV client for the workspace
    pub async fn sync_pull(&self, webdav_client: WebDavClient) -> Result<SyncResult> {
        let engine = SyncEngine::new(self.workspace_path.clone(), webdav_client);
        engine.pull().await
    }

    /// Perform bidirectional sync with WebDAV server
    ///
    /// # Arguments
    /// * `webdav_client` - Configured WebDAV client for the workspace
    pub async fn sync(&self, webdav_client: WebDavClient) -> Result<SyncResult> {
        let engine = SyncEngine::new(self.workspace_path.clone(), webdav_client);
        engine.sync().await
    }

    /// Get sync status for this workspace
    ///
    /// # Arguments
    /// * `webdav_client` - Configured WebDAV client for the workspace
    pub async fn sync_status(&self, webdav_client: WebDavClient) -> Result<SyncStatus> {
        let engine = SyncEngine::new(self.workspace_path.clone(), webdav_client);
        engine.status().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::TaskStatus;
    use tempfile::TempDir;

    #[test]
    fn test_init_repository() {
        let temp_dir = TempDir::new().unwrap();
        let repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        assert_eq!(lists.len(), 1);
        assert_eq!(lists[0].title, "My Tasks");
    }

    #[test]
    fn test_create_and_get_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        let task = Task::new("Test Task".to_string());
        let task_id = task.id;
        repo.create_task(list_id, task).unwrap();

        let retrieved_task = repo.get_task(list_id, task_id).unwrap();
        assert_eq!(retrieved_task.title, "Test Task");
    }

    #[test]
    fn test_complete_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        let task = Task::new("Test Task".to_string());
        let task_id = task.id;
        repo.create_task(list_id, task).unwrap();

        repo.complete_task(list_id, task_id).unwrap();

        let task = repo.get_task(list_id, task_id).unwrap();
        assert_eq!(task.status, TaskStatus::Completed);
    }

    #[test]
    fn test_delete_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        let task = Task::new("Test Task".to_string());
        let task_id = task.id;
        repo.create_task(list_id, task).unwrap();

        repo.delete_task(list_id, task_id).unwrap();

        assert!(repo.get_task(list_id, task_id).is_err());
    }

    #[test]
    fn test_create_list() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        repo.create_list("Work".to_string()).unwrap();

        let lists = repo.get_lists().unwrap();
        assert_eq!(lists.len(), 2);
        assert!(lists.iter().any(|l| l.title == "Work"));
    }

    #[test]
    fn test_task_ordering() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        let task1 = Task::new("Task 1".to_string());
        let task2 = Task::new("Task 2".to_string());
        let task3 = Task::new("Task 3".to_string());

        let id1 = task1.id;
        let id2 = task2.id;
        let id3 = task3.id;

        repo.create_task(list_id, task1).unwrap();
        repo.create_task(list_id, task2).unwrap();
        repo.create_task(list_id, task3).unwrap();

        // Move task3 to position 0
        repo.reorder_task(list_id, id3, 0).unwrap();

        let order = repo.get_task_order(list_id).unwrap();
        assert_eq!(order, vec![id3, id1, id2]);
    }

    #[test]
    fn test_rename_list() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        repo.rename_list(list_id, "Renamed List".to_string())
            .unwrap();

        let lists = repo.get_lists().unwrap();
        assert_eq!(lists[0].title, "Renamed List");
    }

    #[test]
    fn test_archive_list() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        // Initially not archived
        assert!(!lists[0].archived);

        // Archive the list
        repo.archive_list(list_id, true).unwrap();

        let lists = repo.get_lists().unwrap();
        assert!(lists[0].archived);

        // Unarchive the list
        repo.archive_list(list_id, false).unwrap();

        let lists = repo.get_lists().unwrap();
        assert!(!lists[0].archived);
    }

    #[test]
    fn test_reorder_list() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let my_tasks = repo.get_lists().unwrap()[0].id;
        let _list1 = repo.create_list("List 1".to_string()).unwrap();
        let list2 = repo.create_list("List 2".to_string()).unwrap();

        // Initial order: My Tasks, List 1, List 2
        let lists = repo.get_lists().unwrap();
        assert_eq!(lists.len(), 3);
        assert_eq!(lists[0].title, "My Tasks");

        // Move List 2 to position 0
        repo.reorder_list(list2.id, 0).unwrap();

        let lists = repo.get_lists().unwrap();
        assert_eq!(lists[0].title, "List 2");
        assert_eq!(lists[1].title, "My Tasks");
        assert_eq!(lists[2].title, "List 1");

        // Move My Tasks to position 1
        repo.reorder_list(my_tasks, 1).unwrap();

        let lists = repo.get_lists().unwrap();
        assert_eq!(lists[0].title, "List 2");
        assert_eq!(lists[1].title, "My Tasks");
        assert_eq!(lists[2].title, "List 1");
    }

    #[test]
    fn test_find_list_by_name() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        repo.create_list("Work".to_string()).unwrap();

        let list_id = repo.find_list_by_name("Work").unwrap();
        let list = repo.get_list(list_id).unwrap();

        assert_eq!(list.title, "Work");
    }

    #[test]
    fn test_find_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let lists = repo.get_lists().unwrap();
        let list_id = lists[0].id;

        let task = Task::new("Findable Task".to_string());
        let task_id = task.id;
        repo.create_task(list_id, task).unwrap();

        let (found_list_id, found_task) = repo.find_task(task_id).unwrap();

        assert_eq!(found_list_id, list_id);
        assert_eq!(found_task.title, "Findable Task");
    }

    #[test]
    fn test_delete_list() {
        let temp_dir = TempDir::new().unwrap();
        let mut repo = TaskRepository::init(temp_dir.path().to_path_buf()).unwrap();

        let work_list = repo.create_list("Work".to_string()).unwrap();

        repo.delete_list(work_list.id).unwrap();

        let lists = repo.get_lists().unwrap();
        assert_eq!(lists.len(), 1);
        assert!(!lists.iter().any(|l| l.title == "Work"));
    }
}
