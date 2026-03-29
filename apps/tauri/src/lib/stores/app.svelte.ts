import { invoke } from "@tauri-apps/api/core";
import type {
  AppConfig,
  Task,
  TaskList,
  Screen,
  SyncResult,
} from "../types";

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

async function createTask(title: string, description?: string) {
  if (!activeListId) return;
  try {
    const task = await invoke<Task>("create_task", {
      listId: activeListId,
      title,
      description: description ?? "",
    });
    tasks = [...tasks, task];
    error = null;
  } catch (e) {
    error = String(e);
  }
}

async function toggleTask(taskId: string) {
  if (!activeListId) return;
  try {
    const updated = await invoke<Task>("toggle_task", {
      listId: activeListId,
      taskId,
    });
    tasks = tasks.map((t) => (t.id === taskId ? updated : t));
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

async function triggerSync() {
  if (!config?.current_workspace) return;
  const ws = config.workspaces[config.current_workspace];
  if (!ws?.webdav_url) {
    error = "No WebDAV URL configured";
    return;
  }
  syncing = true;
  error = null;
  try {
    const result = await invoke<SyncResult>("sync_workspace", {
      workspacePath: ws.path,
      webdavUrl: ws.webdav_url,
      username: "",
      password: "",
    });
    if (result.errors.length > 0) {
      error = result.errors.join("; ");
    }
    await loadLists();
  } catch (e) {
    error = String(e);
  } finally {
    syncing = false;
  }
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
  triggerSync,
  toggleDarkMode,
  setScreen,
  clearError,
};
