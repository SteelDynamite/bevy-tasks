use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use crate::error::{Error, Result};
use crate::models::{Task, TaskList, TaskStatus};

/// Metadata stored in root .metadata.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RootMetadata {
    pub version: u32,
    pub list_order: Vec<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_opened_list: Option<Uuid>,
}

impl Default for RootMetadata {
    fn default() -> Self {
        Self {
            version: 1,
            list_order: Vec::new(),
            last_opened_list: None,
        }
    }
}

/// Metadata stored in each list's .listdata.json
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

/// Frontmatter for task markdown files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskFrontmatter {
    pub id: Uuid,
    pub status: TaskStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub due: Option<DateTime<Utc>>,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent: Option<Uuid>,
}

impl From<&Task> for TaskFrontmatter {
    fn from(task: &Task) -> Self {
        Self {
            id: task.id,
            status: task.status,
            due: task.due_date,
            created: task.created_at,
            updated: task.updated_at,
            parent: task.parent_id,
        }
    }
}

pub trait Storage {
    fn read_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task>;
    fn write_task(&mut self, list_id: Uuid, task: &Task) -> Result<()>;
    fn delete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()>;
    fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>>;

    fn create_list(&mut self, name: String) -> Result<TaskList>;
    fn get_lists(&self) -> Result<Vec<TaskList>>;
    fn delete_list(&mut self, list_id: Uuid) -> Result<()>;

    fn read_root_metadata(&self) -> Result<RootMetadata>;
    fn write_root_metadata(&mut self, metadata: &RootMetadata) -> Result<()>;

    fn read_list_metadata(&self, list_id: Uuid) -> Result<ListMetadata>;
    fn write_list_metadata(&mut self, metadata: &ListMetadata) -> Result<()>;
}

pub struct FileSystemStorage {
    root_path: PathBuf,
}

impl FileSystemStorage {
    pub fn new(root_path: PathBuf) -> Result<Self> {
        if !root_path.exists() {
            return Err(Error::NotFound(format!("Path does not exist: {:?}", root_path)));
        }
        Ok(Self { root_path })
    }

    pub fn init(root_path: PathBuf) -> Result<Self> {
        fs::create_dir_all(&root_path)?;

        let storage = Self { root_path };

        // Create default metadata if it doesn't exist
        if !storage.metadata_path().exists() {
            storage.write_root_metadata_internal(&RootMetadata::default())?;
        }

        Ok(storage)
    }

    fn metadata_path(&self) -> PathBuf {
        self.root_path.join(".metadata.json")
    }

    fn list_dir_path(&self, list_id: Uuid) -> Result<PathBuf> {
        // Find the directory with this list ID
        let metadata = self.read_root_metadata()?;
        let entries = fs::read_dir(&self.root_path)?;

        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            if path.is_dir() {
                let listdata_path = path.join(".listdata.json");
                if listdata_path.exists() {
                    let content = fs::read_to_string(&listdata_path)?;
                    let list_metadata: ListMetadata = serde_json::from_str(&content)?;
                    if list_metadata.id == list_id {
                        return Ok(path);
                    }
                }
            }
        }

        Err(Error::ListNotFound(list_id.to_string()))
    }

    fn list_dir_path_by_name(&self, name: &str) -> PathBuf {
        self.root_path.join(name)
    }

    fn task_file_path(&self, list_dir: &Path, task: &Task) -> PathBuf {
        list_dir.join(format!("{}.md", task.title))
    }

    fn parse_markdown_with_frontmatter(&self, content: &str) -> Result<(TaskFrontmatter, String)> {
        let lines: Vec<&str> = content.lines().collect();

        if lines.is_empty() || lines[0] != "---" {
            return Err(Error::InvalidData("Missing frontmatter delimiter".to_string()));
        }

        // Find closing ---
        let end_idx = lines[1..]
            .iter()
            .position(|&line| line == "---")
            .ok_or_else(|| Error::InvalidData("Missing closing frontmatter delimiter".to_string()))?;

        let frontmatter_lines = &lines[1..=end_idx];
        let frontmatter_str = frontmatter_lines.join("\n");
        let frontmatter: TaskFrontmatter = serde_yaml::from_str(&frontmatter_str)?;

        let description = if end_idx + 2 < lines.len() {
            lines[end_idx + 2..].join("\n")
        } else {
            String::new()
        };

        Ok((frontmatter, description.trim().to_string()))
    }

    fn write_markdown_with_frontmatter(&self, task: &Task) -> Result<String> {
        let frontmatter = TaskFrontmatter::from(task);
        let yaml = serde_yaml::to_string(&frontmatter)?;

        let mut content = String::new();
        content.push_str("---\n");
        content.push_str(&yaml);
        content.push_str("---\n\n");
        content.push_str(&task.description);

        Ok(content)
    }

    fn read_root_metadata_internal(&self) -> Result<RootMetadata> {
        let path = self.metadata_path();
        if !path.exists() {
            return Ok(RootMetadata::default());
        }
        let content = fs::read_to_string(&path)?;
        let metadata = serde_json::from_str(&content)?;
        Ok(metadata)
    }

    fn write_root_metadata_internal(&self, metadata: &RootMetadata) -> Result<()> {
        let path = self.metadata_path();
        let content = serde_json::to_string_pretty(&metadata)?;
        fs::write(&path, content)?;
        Ok(())
    }
}

impl Storage for FileSystemStorage {
    fn read_task(&self, list_id: Uuid, task_id: Uuid) -> Result<Task> {
        let list_dir = self.list_dir_path(list_id)?;

        // Read all task files in the list directory
        let entries = fs::read_dir(&list_dir)?;

        for entry in entries {
            let entry = entry?;
            let path = entry.path();

            if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("md") {
                let content = fs::read_to_string(&path)?;
                let (frontmatter, description) = self.parse_markdown_with_frontmatter(&content)?;

                if frontmatter.id == task_id {
                    let title = path.file_stem()
                        .and_then(|s| s.to_str())
                        .ok_or_else(|| Error::InvalidData("Invalid filename".to_string()))?
                        .to_string();

                    return Ok(Task {
                        id: frontmatter.id,
                        title,
                        description,
                        status: frontmatter.status,
                        due_date: frontmatter.due,
                        created_at: frontmatter.created,
                        updated_at: frontmatter.updated,
                        parent_id: frontmatter.parent,
                    });
                }
            }
        }

        Err(Error::TaskNotFound(task_id.to_string()))
    }

    fn write_task(&mut self, list_id: Uuid, task: &Task) -> Result<()> {
        let list_dir = self.list_dir_path(list_id)?;
        let task_path = self.task_file_path(&list_dir, task);

        let content = self.write_markdown_with_frontmatter(task)?;
        fs::write(&task_path, content)?;

        // Update list metadata to include this task in task_order if not already present
        let mut list_metadata = self.read_list_metadata(list_id)?;
        if !list_metadata.task_order.contains(&task.id) {
            list_metadata.task_order.push(task.id);
            list_metadata.updated_at = Utc::now();
            self.write_list_metadata(&list_metadata)?;
        }

        Ok(())
    }

    fn delete_task(&mut self, list_id: Uuid, task_id: Uuid) -> Result<()> {
        let task = self.read_task(list_id, task_id)?;
        let list_dir = self.list_dir_path(list_id)?;
        let task_path = self.task_file_path(&list_dir, &task);

        fs::remove_file(&task_path)?;

        // Remove from task_order
        let mut list_metadata = self.read_list_metadata(list_id)?;
        list_metadata.task_order.retain(|&id| id != task_id);
        list_metadata.updated_at = Utc::now();
        self.write_list_metadata(&list_metadata)?;

        Ok(())
    }

    fn list_tasks(&self, list_id: Uuid) -> Result<Vec<Task>> {
        let list_dir = self.list_dir_path(list_id)?;
        let list_metadata = self.read_list_metadata(list_id)?;

        let mut tasks = Vec::new();
        let entries = fs::read_dir(&list_dir)?;

        for entry in entries {
            let entry = entry?;
            let path = entry.path();

            if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("md") {
                let content = fs::read_to_string(&path)?;
                let (frontmatter, description) = self.parse_markdown_with_frontmatter(&content)?;

                let title = path.file_stem()
                    .and_then(|s| s.to_str())
                    .ok_or_else(|| Error::InvalidData("Invalid filename".to_string()))?
                    .to_string();

                let task = Task {
                    id: frontmatter.id,
                    title,
                    description,
                    status: frontmatter.status,
                    due_date: frontmatter.due,
                    created_at: frontmatter.created,
                    updated_at: frontmatter.updated,
                    parent_id: frontmatter.parent,
                };

                tasks.push(task);
            }
        }

        // Sort by task_order
        let order_map: HashMap<Uuid, usize> = list_metadata.task_order
            .iter()
            .enumerate()
            .map(|(i, &id)| (id, i))
            .collect();

        tasks.sort_by_key(|task| order_map.get(&task.id).copied().unwrap_or(usize::MAX));

        Ok(tasks)
    }

    fn create_list(&mut self, name: String) -> Result<TaskList> {
        let list_dir = self.list_dir_path_by_name(&name);

        if list_dir.exists() {
            return Err(Error::InvalidData(format!("List '{}' already exists", name)));
        }

        fs::create_dir_all(&list_dir)?;

        let list_id = Uuid::new_v4();
        let list_metadata = ListMetadata::new(list_id);

        let metadata_path = list_dir.join(".listdata.json");
        let content = serde_json::to_string_pretty(&list_metadata)?;
        fs::write(&metadata_path, content)?;

        // Add to root metadata
        let mut root_metadata = self.read_root_metadata_internal()?;
        root_metadata.list_order.push(list_id);
        if root_metadata.last_opened_list.is_none() {
            root_metadata.last_opened_list = Some(list_id);
        }
        self.write_root_metadata_internal(&root_metadata)?;

        let task_list = TaskList {
            id: list_id,
            title: name,
            tasks: Vec::new(),
            created_at: list_metadata.created_at,
            updated_at: list_metadata.updated_at,
            group_by_due_date: list_metadata.group_by_due_date,
        };

        Ok(task_list)
    }

    fn get_lists(&self) -> Result<Vec<TaskList>> {
        let root_metadata = self.read_root_metadata_internal()?;
        let mut lists = Vec::new();

        let entries = fs::read_dir(&self.root_path)?;

        for entry in entries {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let listdata_path = path.join(".listdata.json");
                if listdata_path.exists() {
                    let content = fs::read_to_string(&listdata_path)?;
                    let list_metadata: ListMetadata = serde_json::from_str(&content)?;

                    let title = path.file_name()
                        .and_then(|s| s.to_str())
                        .ok_or_else(|| Error::InvalidData("Invalid directory name".to_string()))?
                        .to_string();

                    let tasks = self.list_tasks(list_metadata.id)?;

                    let task_list = TaskList {
                        id: list_metadata.id,
                        title,
                        tasks,
                        created_at: list_metadata.created_at,
                        updated_at: list_metadata.updated_at,
                        group_by_due_date: list_metadata.group_by_due_date,
                    };

                    lists.push(task_list);
                }
            }
        }

        // Sort by list_order
        let order_map: HashMap<Uuid, usize> = root_metadata.list_order
            .iter()
            .enumerate()
            .map(|(i, &id)| (id, i))
            .collect();

        lists.sort_by_key(|list| order_map.get(&list.id).copied().unwrap_or(usize::MAX));

        Ok(lists)
    }

    fn delete_list(&mut self, list_id: Uuid) -> Result<()> {
        let list_dir = self.list_dir_path(list_id)?;

        fs::remove_dir_all(&list_dir)?;

        // Remove from root metadata
        let mut root_metadata = self.read_root_metadata_internal()?;
        root_metadata.list_order.retain(|&id| id != list_id);
        if root_metadata.last_opened_list == Some(list_id) {
            root_metadata.last_opened_list = root_metadata.list_order.first().copied();
        }
        self.write_root_metadata_internal(&root_metadata)?;

        Ok(())
    }

    fn read_root_metadata(&self) -> Result<RootMetadata> {
        self.read_root_metadata_internal()
    }

    fn write_root_metadata(&mut self, metadata: &RootMetadata) -> Result<()> {
        self.write_root_metadata_internal(metadata)
    }

    fn read_list_metadata(&self, list_id: Uuid) -> Result<ListMetadata> {
        let list_dir = self.list_dir_path(list_id)?;
        let metadata_path = list_dir.join(".listdata.json");

        if !metadata_path.exists() {
            return Err(Error::NotFound(format!("List metadata not found: {}", list_id)));
        }

        let content = fs::read_to_string(&metadata_path)?;
        let metadata = serde_json::from_str(&content)?;
        Ok(metadata)
    }

    fn write_list_metadata(&mut self, metadata: &ListMetadata) -> Result<()> {
        let list_dir = self.list_dir_path(metadata.id)?;
        let metadata_path = list_dir.join(".listdata.json");

        let content = serde_json::to_string_pretty(&metadata)?;
        fs::write(&metadata_path, content)?;
        Ok(())
    }
}
