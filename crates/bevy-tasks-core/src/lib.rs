//! # bevy-tasks-core
//!
//! Core library for the Bevy Tasks application.
//! Provides data models, storage, and repository for managing tasks.

pub mod config;
pub mod error;
pub mod models;
pub mod repository;
pub mod storage;

pub use config::{AppConfig, WorkspaceConfig};
pub use error::{Error, Result};
pub use models::{Task, TaskList, TaskStatus};
pub use repository::TaskRepository;
pub use storage::{FileSystemStorage, Storage};
