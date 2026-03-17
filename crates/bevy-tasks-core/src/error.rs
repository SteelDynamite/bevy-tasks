use std::io;
use std::fmt;

#[derive(Debug)]
pub enum Error {
    Io(io::Error),
    Serialization(String),
    NotFound(String),
    InvalidData(String),
    WorkspaceNotFound(String),
    ListNotFound(String),
    TaskNotFound(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Io(e) => write!(f, "IO error: {}", e),
            Error::Serialization(msg) => write!(f, "Serialization error: {}", msg),
            Error::NotFound(msg) => write!(f, "Not found: {}", msg),
            Error::InvalidData(msg) => write!(f, "Invalid data: {}", msg),
            Error::WorkspaceNotFound(name) => write!(f, "Workspace not found: {}", name),
            Error::ListNotFound(id) => write!(f, "List not found: {}", id),
            Error::TaskNotFound(id) => write!(f, "Task not found: {}", id),
        }
    }
}

impl std::error::Error for Error {}

impl From<io::Error> for Error {
    fn from(err: io::Error) -> Self {
        Error::Io(err)
    }
}

impl From<serde_json::Error> for Error {
    fn from(err: serde_json::Error) -> Self {
        Error::Serialization(err.to_string())
    }
}

impl From<serde_yaml::Error> for Error {
    fn from(err: serde_yaml::Error) -> Self {
        Error::Serialization(err.to_string())
    }
}

pub type Result<T> = std::result::Result<T, Error>;
