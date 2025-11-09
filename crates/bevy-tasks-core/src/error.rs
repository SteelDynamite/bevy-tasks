use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    SerdeJson(#[from] serde_json::Error),

    #[error("YAML error: {0}")]
    SerdeYaml(#[from] serde_yaml::Error),

    #[error("Task not found: {0}")]
    TaskNotFound(uuid::Uuid),

    #[error("List not found: {0}")]
    ListNotFound(uuid::Uuid),

    #[error("Workspace not found: {0}")]
    WorkspaceNotFound(String),

    #[error("Workspace already exists: {0}")]
    WorkspaceAlreadyExists(String),

    #[error("No current workspace set")]
    NoCurrentWorkspace,

    #[error("Invalid task file: {0}")]
    InvalidTaskFile(String),

    #[error("Invalid metadata file: {0}")]
    InvalidMetadata(String),

    #[error("Path error: {0}")]
    PathError(String),

    #[error("Cannot remove current workspace")]
    CannotRemoveCurrentWorkspace,

    #[error("Other error: {0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, Error>;
