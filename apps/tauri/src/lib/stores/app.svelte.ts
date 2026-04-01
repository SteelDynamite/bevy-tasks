import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import type {
  AppConfig,
  Task,
  TaskList,
  Screen,
  SyncResult,
} from "../types";

// Listen for file system changes from the backend watcher
listen("fs-changed", () => {
  loadLists();
});

// ── Reactive state ───────────────────────────────────────────────────

let screen = $state<Screen>("setup");
let config = $state<AppConfig | null>(null);
let lists = $state<TaskList[]>([]);
let activeListId = $state<string | null>(null);
let tasks = $state<Task[]>([]);
let darkMode = $state(
  globalThis.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false,
);
let syncing = $state(false);
let syncMode = $state<"full" | "push" | "pull">("full");
let lastSyncResult = $state<SyncResult | null>(null);
let error = $state<string | null>(null);

// ── Derived ──────────────────────────────────────────────────────────

let activeList = $derived(lists.find((l) => l.id === activeListId) ?? null);
let pendingTasks = $derived(tasks.filter((t) => t.status === "backlog"));
let completedTasks = $derived(tasks.filter((t) => t.status === "completed"));
let hasWorkspace = $derived(
  config !== null &&
    config.current_workspace !== null &&
    Object.keys(config.workspaces).length > 0,
);

// ── Actions ──────────────────────────────────────────────────────────

async function loadConfig() {
  try {
    config = await invoke<AppConfig>("get_config");
    if (hasWorkspace) {
      screen = "tasks";
      await loadLists();
    } else {
      screen = "setup";
    }
  } catch (e) {
    config = { workspaces: {}, current_workspace: null };
    screen = "setup";
  }
}

async function addWorkspace(name: string, path: string) {
  try {
    await invoke("init_workspace", { path });
    await invoke("add_workspace", { name, path });
    config = await invoke<AppConfig>("get_config");
    await loadLists();
    invoke("watch_workspace", { path }).catch(() => {});
    screen = "tasks";
    error = null;
  } catch (e) {
    error = String(e);
  }
}

async function switchWorkspace(name: string) {
  try {
    await invoke("set_current_workspace", { name });
    config = await invoke<AppConfig>("get_config");
    activeListId = null;
    await loadLists();
    const ws = config?.workspaces[name];
    if (ws) invoke("watch_workspace", { path: ws.path }).catch(() => {});
    error = null;
  } catch (e) {
    error = String(e);
  }
}

async function removeWorkspace(name: string) {
  try {
    await invoke("remove_workspace", { name });
    config = await invoke<AppConfig>("get_config");
    if (!hasWorkspace) {
      screen = "setup";
      lists = [];
      tasks = [];
      activeListId = null;
    }
  } catch (e) {
    error = String(e);
  }
}

async function loadLists() {
  try {
    lists = await invoke<TaskList[]>("get_lists");
    if (lists.length > 0 && !activeListId) {
      activeListId = lists[0].id;
    }
    if (activeListId) await loadTasks();
  } catch (e) {
    error = String(e);
  }
}

async function loadTasks() {
  if (!activeListId) return;
  try {
    tasks = await invoke<Task[]>("list_tasks", { listId: activeListId });
  } catch (e) {
    error = String(e);
  }
}

async function selectList(id: string) {
  activeListId = id;
  await loadTasks();
}

async function createList(name: string) {
  try {
    const list = await invoke<TaskList>("create_list", { name });
    lists = [...lists, list];
    activeListId = list.id;
    tasks = [];
    error = null;
  } catch (e) {
    error = String(e);
  }
}

async function deleteList(id: string) {
  try {
    await invoke("delete_list", { listId: id });
    lists = lists.filter((l) => l.id !== id);
    if (activeListId === id) {
      activeListId = lists.length > 0 ? lists[0].id : null;
      if (activeListId) await loadTasks();
      else tasks = [];
    }
  } catch (e) {
    error = String(e);
  }
}

async function createTask(title: string, description?: string): Promise<Task | null> {
  if (!activeListId) return null;
  try {
    const task = await invoke<Task>("create_task", {
      listId: activeListId,
      title,
      description: description ?? "",
    });
    tasks = [...tasks, task];
    error = null;
    return task;
  } catch (e) {
    error = String(e);
    return null;
  }
}

async function toggleTask(taskId: string) {
  if (!activeListId) return;
  try {
    const updated = await invoke<Task>("toggle_task", {
      listId: activeListId,
      taskId,
    });
    // Move to top of list locally, then persist order in background
    if (updated.status === "backlog") {
      tasks = [updated, ...tasks.filter((t) => t.id !== taskId)];
      invoke("reorder_task", { listId: activeListId, taskId, newPosition: 0 }).catch(() => {});
    } else {
      tasks = tasks.map((t) => (t.id === taskId ? updated : t));
    }
  } catch (e) {
    error = String(e);
  }
}

async function updateTask(task: Task) {
  if (!activeListId) return;
  try {
    await invoke("update_task", { listId: activeListId, task });
    tasks = tasks.map((t) => (t.id === task.id ? task : t));
  } catch (e) {
    error = String(e);
  }
}

async function reorderTask(taskId: string, newPosition: number) {
  if (!activeListId) return;
  try {
    await invoke("reorder_task", { listId: activeListId, taskId, newPosition });
    await loadTasks();
  } catch (e) {
    error = String(e);
  }
}

async function deleteTask(taskId: string) {
  if (!activeListId) return;
  try {
    await invoke("delete_task", { listId: activeListId, taskId });
    tasks = tasks.filter((t) => t.id !== taskId);
  } catch (e) {
    error = String(e);
  }
}

async function moveTask(taskId: string, targetListId: string) {
  if (!activeListId) return;
  try {
    await invoke("move_task", {
      fromListId: activeListId,
      toListId: targetListId,
      taskId,
    });
    tasks = tasks.filter((t) => t.id !== taskId);
  } catch (e) {
    error = String(e);
  }
}

async function renameList(listId: string, newName: string) {
  try {
    await invoke("rename_list", { listId, newName });
    lists = lists.map((l) =>
      l.id === listId ? { ...l, title: newName } : l,
    );
  } catch (e) {
    error = String(e);
  }
}

async function setGroupByDueDate(listId: string, enabled: boolean) {
  try {
    await invoke("set_group_by_due_date", { listId, enabled });
    lists = lists.map((l) =>
      l.id === listId ? { ...l, group_by_due_date: enabled } : l,
    );
    if (listId === activeListId) await loadTasks();
  } catch (e) {
    error = String(e);
  }
}

async function triggerSync() {
  if (!config?.current_workspace) return;
  const workspaceName = config.current_workspace;
  const ws = config.workspaces[workspaceName];
  if (!ws?.webdav_url) {
    error = "No WebDAV URL configured";
    return;
  }
  syncing = true;
  error = null;
  try {
    const domain = new URL(ws.webdav_url).hostname;
    const [username, password] = await invoke<[string, string]>("load_credentials", { domain });
    const result = await invoke<SyncResult>("sync_workspace", {
      workspaceName,
      workspacePath: ws.path,
      webdavUrl: ws.webdav_url,
      username,
      password,
      mode: syncMode,
    });
    lastSyncResult = result;
    if (result.errors.length > 0) {
      error = result.errors.join("; ");
    }
    // Reload config to pick up updated last_sync timestamp
    config = await invoke<AppConfig>("get_config");
    await loadLists();
  } catch (e) {
    error = String(e);
  } finally {
    syncing = false;
  }
}

function setSyncMode(mode: "full" | "push" | "pull") {
  syncMode = mode;
}

function toggleDarkMode() {
  darkMode = !darkMode;
}

function setScreen(s: Screen) {
  screen = s;
}

function clearError() {
  error = null;
}

// ── Exports ──────────────────────────────────────────────────────────

export const app = {
  get screen() {
    return screen;
  },
  get config() {
    return config;
  },
  get lists() {
    return lists;
  },
  get activeListId() {
    return activeListId;
  },
  get activeList() {
    return activeList;
  },
  get tasks() {
    return tasks;
  },
  get pendingTasks() {
    return pendingTasks;
  },
  get completedTasks() {
    return completedTasks;
  },
  get darkMode() {
    return darkMode;
  },
  get syncing() {
    return syncing;
  },
  get syncMode() {
    return syncMode;
  },
  get lastSyncResult() {
    return lastSyncResult;
  },
  get error() {
    return error;
  },
  get hasWorkspace() {
    return hasWorkspace;
  },
  loadConfig,
  addWorkspace,
  switchWorkspace,
  removeWorkspace,
  loadLists,
  loadTasks,
  selectList,
  createList,
  deleteList,
  createTask,
  toggleTask,
  updateTask,
  reorderTask,
  deleteTask,
  moveTask,
  renameList,
  setGroupByDueDate,
  triggerSync,
  setSyncMode,
  toggleDarkMode,
  setScreen,
  clearError,
};
