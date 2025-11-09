use crate::error::{Error, Result};
use crate::models::{GlobalMetadata, ListMetadata, Task, TaskStatus};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

const METADATA_FILE: &str = ".metadata.json";
const LIST_METADATA_FILE: &str = ".listdata.json";

/// Frontmatter data stored in YAML at the top of each task file
#[derive(Debug, Serialize, Deserialize)]
struct TaskFrontmatter {
    id: Uuid,
    status: TaskStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    due: Option<DateTime<Utc>>,
    created: DateTime<Utc>,
    updated: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    parent: Option<Uuid>,
}

/// Storage trait for task persistence
pub trait Storage {
    fn init(&mut self) -> Result<()>;
    fn read_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task>;
    fn write_task(&mut self, list_id: Uuid, task: &Task) -> Result<()>;
    fn delete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()>;
    fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>>;
    fn create_list(&mut self, name: &str) -> Result<Uuid>;
    fn list_lists(&self) -> Result<Vec<(Uuid, String)>>;
    fn delete_list(&mut self, list_id: Uuid) -> Result<()>;
    fn read_global_metadata(&self) -> Result<GlobalMetadata>;
    fn write_global_metadata(&mut self, metadata: &GlobalMetadata) -> Result<()>;
    fn read_list_metadata(&self, list_id: Uuid) -> Result<ListMetadata>;
    fn write_list_metadata(&mut self, metadata: &ListMetadata) -> Result<()>;
}

/// File system based storage implementation
pub struct FileSystemStorage {
    root_path: PathBuf,
    list_paths: HashMap<Uuid, PathBuf>,
}

impl FileSystemStorage {
    pub fn new(root_path: PathBuf) -> Result<Self> {
        let mut storage = Self {
            root_path,
            list_paths: HashMap::new(),
        };

        // Load list paths if root exists
        if storage.root_path.exists() {
            storage.load_list_paths()?;
        }

        Ok(storage)
    }

    fn load_list_paths(&mut self) -> Result<()> {
        self.list_paths.clear();

        for entry in fs::read_dir(&self.root_path)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let list_metadata_path = path.join(LIST_METADATA_FILE);
                if list_metadata_path.exists() {
                    let contents = fs::read_to_string(&list_metadata_path)?;
                    let metadata: ListMetadata = serde_json::from_str(&contents)?;
                    self.list_paths.insert(metadata.id, path);
                }
            }
        }

        Ok(())
    }

    fn get_list_path(&self, list_id: Uuid) -> Result<&PathBuf> {
        self.list_paths
            .get(&list_id)
            .ok_or(Error::ListNotFound(list_id))
    }

    fn parse_task_file(&self, title: String, content: &str) -> Result<Task> {
        // Split frontmatter and description
        let parts: Vec<&str> = content.splitn(3, "---").collect();

        if parts.len() < 3 {
            return Err(Error::InvalidTaskFile(
                "Missing frontmatter delimiters".to_string(),
            ));
        }

        // Parse YAML frontmatter
        let frontmatter: TaskFrontmatter = serde_yaml::from_str(parts[1].trim())?;

        // Get description (everything after second ---)
        let description = parts[2].trim().to_string();

        Ok(Task {
            id: frontmatter.id,
            title,
            description,
            status: frontmatter.status,
            due_date: frontmatter.due,
            created_at: frontmatter.created,
            updated_at: frontmatter.updated,
            parent_id: frontmatter.parent,
        })
    }

    fn serialize_task(&self, task: &Task) -> Result<String> {
        let frontmatter = TaskFrontmatter {
            id: task.id,
            status: task.status,
            due: task.due_date,
            created: task.created_at,
            updated: task.updated_at,
            parent: task.parent_id,
        };

        let yaml = serde_yaml::to_string(&frontmatter)?;

        Ok(format!("---\n{}---\n\n{}\n", yaml, task.description))
    }

    fn sanitize_filename(name: &str) -> String {
        // Remove or replace characters that are invalid in filenames
        name.chars()
            .map(|c| match c {
                '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
                _ => c,
            })
            .collect()
    }
}

impl Storage for FileSystemStorage {
    fn init(&mut self) -> Result<()> {
        fs::create_dir_all(&self.root_path)?;

        // Create .metadata.json if it doesn't exist
        let metadata_path = self.root_path.join(METADATA_FILE);
        if !metadata_path.exists() {
            let metadata = GlobalMetadata::default();
            self.write_global_metadata(&metadata)?;
        }

        Ok(())
    }

    fn read_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task> {
        let list_path = self.get_list_path(list_id)?;

        // Try to find the task file by reading all .md files and checking their IDs
        for entry in fs::read_dir(list_path)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                let content = fs::read_to_string(&path)?;
                let title = path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| Error::InvalidTaskFile("Invalid filename".to_string()))?
                    .to_string();

                let task = self.parse_task_file(title, &content)?;
                if task.id == task_id {
                    return Ok(task);
                }
            }
        }

        Err(Error::TaskNotFound(task_id))
    }

    fn write_task(&mut self, list_id: Uuid, task: &Task) -> Result<()> {
        let list_path = self.get_list_path(list_id)?;
        let filename = format!("{}.md", Self::sanitize_filename(&task.title));
        let task_path = list_path.join(filename);

        let content = self.serialize_task(task)?;
        fs::write(&task_path, content)?;

        Ok(())
    }

    fn delete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()> {
        let list_path = self.get_list_path(list_id)?;

        // Find and delete the task file
        for entry in fs::read_dir(list_path)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                let content = fs::read_to_string(&path)?;
                let title = path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| Error::InvalidTaskFile("Invalid filename".to_string()))?
                    .to_string();

                let task = self.parse_task_file(title, &content)?;
                if task.id == task_id {
                    fs::remove_file(&path)?;
                    return Ok(());
                }
            }
        }

        Err(Error::TaskNotFound(task_id))
    }

    fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>> {
        let list_path = self.get_list_path(list_id)?;
        let mut tasks = Vec::new();

        for entry in fs::read_dir(list_path)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                let content = fs::read_to_string(&path)?;
                let title = path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| Error::InvalidTaskFile("Invalid filename".to_string()))?
                    .to_string();

                let task = self.parse_task_file(title, &content)?;
                tasks.push(task);
            }
        }

        Ok(tasks)
    }

    fn create_list(&mut self, name: &str) -> Result<Uuid> {
        let list_id = Uuid::new_v4();
        let list_path = self.root_path.join(Self::sanitize_filename(name));

        fs::create_dir_all(&list_path)?;

        // Create list metadata
        let metadata = ListMetadata::new(list_id);
        let metadata_path = list_path.join(LIST_METADATA_FILE);
        let contents = serde_json::to_string_pretty(&metadata)?;
        fs::write(&metadata_path, contents)?;

        // Update internal map
        self.list_paths.insert(list_id, list_path);

        // Update global metadata
        let mut global_metadata = self.read_global_metadata()?;
        global_metadata.list_order.push(list_id);
        if global_metadata.last_opened_list.is_none() {
            global_metadata.last_opened_list = Some(list_id);
        }
        self.write_global_metadata(&global_metadata)?;

        Ok(list_id)
    }

    fn list_lists(&self) -> Result<Vec<(Uuid, String)>> {
        let mut lists = Vec::new();

        for entry in fs::read_dir(&self.root_path)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let list_metadata_path = path.join(LIST_METADATA_FILE);
                if list_metadata_path.exists() {
                    let contents = fs::read_to_string(&list_metadata_path)?;
                    let metadata: ListMetadata = serde_json::from_str(&contents)?;

                    let title = path
                        .file_name()
                        .and_then(|s| s.to_str())
                        .ok_or_else(|| Error::InvalidMetadata("Invalid list folder name".to_string()))?
                        .to_string();

                    lists.push((metadata.id, title));
                }
            }
        }

        Ok(lists)
    }

    fn delete_list(&mut self, list_id: Uuid) -> Result<()> {
        let list_path = self.get_list_path(list_id)?.clone();
        fs::remove_dir_all(&list_path)?;

        self.list_paths.remove(&list_id);

        // Update global metadata
        let mut global_metadata = self.read_global_metadata()?;
        global_metadata.list_order.retain(|&id| id != list_id);
        if global_metadata.last_opened_list == Some(list_id) {
            global_metadata.last_opened_list = global_metadata.list_order.first().copied();
        }
        self.write_global_metadata(&global_metadata)?;

        Ok(())
    }

    fn read_global_metadata(&self) -> Result<GlobalMetadata> {
        let metadata_path = self.root_path.join(METADATA_FILE);

        if !metadata_path.exists() {
            return Ok(GlobalMetadata::default());
        }

        let contents = fs::read_to_string(&metadata_path)?;
        let metadata: GlobalMetadata = serde_json::from_str(&contents)?;
        Ok(metadata)
    }

    fn write_global_metadata(&mut self, metadata: &GlobalMetadata) -> Result<()> {
        let metadata_path = self.root_path.join(METADATA_FILE);
        let contents = serde_json::to_string_pretty(metadata)?;
        fs::write(&metadata_path, contents)?;
        Ok(())
    }

    fn read_list_metadata(&self, list_id: Uuid) -> Result<ListMetadata> {
        let list_path = self.get_list_path(list_id)?;
        let metadata_path = list_path.join(LIST_METADATA_FILE);

        let contents = fs::read_to_string(&metadata_path)?;
        let metadata: ListMetadata = serde_json::from_str(&contents)?;
        Ok(metadata)
    }

    fn write_list_metadata(&mut self, metadata: &ListMetadata) -> Result<()> {
        let list_path = self.get_list_path(metadata.id)?;
        let metadata_path = list_path.join(LIST_METADATA_FILE);

        let contents = serde_json::to_string_pretty(metadata)?;
        fs::write(&metadata_path, contents)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_init_storage() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = FileSystemStorage::new(temp_dir.path().to_path_buf()).unwrap();

        storage.init().unwrap();

        assert!(temp_dir.path().join(METADATA_FILE).exists());
    }

    #[test]
    fn test_create_list() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = FileSystemStorage::new(temp_dir.path().to_path_buf()).unwrap();
        storage.init().unwrap();

        let list_id = storage.create_list("Test List").unwrap();

        let lists = storage.list_lists().unwrap();
        assert_eq!(lists.len(), 1);
        assert_eq!(lists[0].0, list_id);
        assert_eq!(lists[0].1, "Test List");
    }

    #[test]
    fn test_write_and_read_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = FileSystemStorage::new(temp_dir.path().to_path_buf()).unwrap();
        storage.init().unwrap();

        let list_id = storage.create_list("Test List").unwrap();
        let task = Task::new("Test Task".to_string());

        storage.write_task(list_id, &task).unwrap();
        let read_task = storage.read_task(list_id, task.id).unwrap();

        assert_eq!(read_task.id, task.id);
        assert_eq!(read_task.title, task.title);
    }

    #[test]
    fn test_delete_task() {
        let temp_dir = TempDir::new().unwrap();
        let mut storage = FileSystemStorage::new(temp_dir.path().to_path_buf()).unwrap();
        storage.init().unwrap();

        let list_id = storage.create_list("Test List").unwrap();
        let task = Task::new("Test Task".to_string());

        storage.write_task(list_id, &task).unwrap();
        storage.delete_task(list_id, task.id).unwrap();

        assert!(storage.read_task(list_id, task.id).is_err());
    }
}
