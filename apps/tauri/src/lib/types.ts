export interface Task {
  id: string;
  title: string;
  description: string;
  status: "backlog" | "completed";
  due_date: string | null;
  created_at: string;
  updated_at: string;
  parent_id: string | null;
}

export interface TaskList {
  id: string;
  title: string;
  tasks: Task[];
  created_at: string;
  updated_at: string;
  group_by_due_date: boolean;
}

export interface WorkspaceConfig {
  path: string;
  webdav_url: string | null;
  last_sync: string | null;
}

export interface AppConfig {
  workspaces: Record<string, WorkspaceConfig>;
  current_workspace: string | null;
}

export interface SyncResult {
  uploaded: number;
  downloaded: number;
  deleted_local: number;
  deleted_remote: number;
  conflicts: number;
  errors: string[];
}

export type Screen = "setup" | "tasks" | "settings";
