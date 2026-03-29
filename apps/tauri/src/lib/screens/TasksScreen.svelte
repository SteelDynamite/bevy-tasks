<script lang="ts">
  import { app } from "../stores/app.svelte";
  import TaskItem from "../components/TaskItem.svelte";
  import NewTaskInput, { newTaskState } from "../components/NewTaskInput.svelte";
  import SettingsScreen from "./SettingsScreen.svelte";

  let showDrawer = $state(false);
  let showSettings = $state(false);
  let showNewList = $state(false);
  let showWorkspacePicker = $state(false);
  let workspacePickerEl = $state<HTMLDivElement | null>(null);

  function handleWindowClick(e: MouseEvent) {
    if (showWorkspacePicker && workspacePickerEl && !workspacePickerEl.contains(e.target as Node)) {
      showWorkspacePicker = false;
    }
    const target = e.target as HTMLElement;
    if (listMenuId && !target.closest("[data-list-menu]")) listMenuId = null;
    if (wsMenuName && !target.closest("[data-ws-menu]")) wsMenuName = null;
  }

  if (typeof window !== "undefined") {
    window.addEventListener("mousedown", handleWindowClick);
  }
  let newListName = $state("");
  let showCompleted = $state(true);
  let listMenuId = $state<string | null>(null);
  let wsMenuName = $state<string | null>(null);
  let dragId = $state<string | null>(null);
  let dragOverId = $state<string | null>(null);
  let resizing = $state(false);
  let resizeTimer: ReturnType<typeof setTimeout>;

  if (typeof window !== "undefined") {
    window.addEventListener("resize", () => {
      resizing = true;
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => (resizing = false), 150);
    });
  }

  async function handleNewList() {
    if (!newListName.trim()) return;
    await app.createList(newListName.trim());
    newListName = "";
    showNewList = false;
  }

  async function handleDeleteList(id: string) {
    listMenuId = null;
    await app.deleteList(id);
  }

  function handleDragStart(e: DragEvent, taskId: string) {
    dragId = taskId;
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", taskId);
      const el = (e.target as HTMLElement).closest("[draggable]") as HTMLElement;
      if (el) {
        const clone = el.cloneNode(true) as HTMLElement;
        clone.style.width = `${el.offsetWidth}px`;
        clone.style.position = "absolute";
        clone.style.top = "-9999px";
        clone.style.left = "-9999px";
        if (app.darkMode) {
          clone.classList.add("dark");
          clone.style.backgroundColor = "var(--color-surface-dark)";
          clone.style.color = "var(--color-text-dark)";
        }
        clone.style.opacity = "0.85";
        clone.style.borderRadius = "8px";
        clone.style.overflow = "hidden";
        clone.style.boxShadow = "0 4px 12px rgba(0,0,0,0.3)";
        document.body.appendChild(clone);
        e.dataTransfer.setDragImage(clone, e.offsetX, e.offsetY);
        requestAnimationFrame(() => clone.remove());
      }
    }
  }

  function handleDragOver(e: DragEvent, taskId: string) {
    e.preventDefault();
    if (e.dataTransfer) e.dataTransfer.dropEffect = "move";
    dragOverId = taskId;
  }

  function handleDragEnd() {
    dragId = null;
    dragOverId = null;
  }

  async function handleDrop(e: DragEvent, targetId: string) {
    e.preventDefault();
    if (!dragId || dragId === targetId) { handleDragEnd(); return; }
    const targetIndex = app.pendingTasks.findIndex((t) => t.id === targetId);
    if (targetIndex >= 0) await app.reorderTask(dragId, targetIndex);
    handleDragEnd();
  }

  function closeDrawer() {
    showDrawer = false;
    showNewList = false;
    listMenuId = null;
  }

  function openSettings() {
    showSettings = true;
  }

  function closeSettings() {
    showSettings = false;
  }

  let workspaceNames = $derived(app.config ? Object.keys(app.config.workspaces) : []);
  let translateX = $derived(showDrawer ? '0' : '-80vw');
</script>

<!-- Viewport clip -->
<div class="h-screen w-screen overflow-hidden">
<!-- Sliding container: left drawer + main content -->
<div
  class="flex h-full ease-out {resizing ? '' : 'transition-transform duration-250'}"
  style="width: calc(100vw + 80vw); transform: translateX({translateX})"
>
  <!-- Drawer panel -->
  <div class="flex h-full w-[80vw] shrink-0 flex-col bg-surface-light dark:bg-surface-dark">
    <!-- List items + new list button -->
    <div class="flex-1 overflow-y-auto py-2">
      {#each app.lists as list (list.id)}
        <div class="group relative flex items-center px-2 hover:bg-black/5 dark:hover:bg-white/10">
          <button
            onclick={() => { app.selectList(list.id); closeDrawer(); }}
            class="flex flex-1 items-center gap-2 px-3 py-2.5 text-left text-sm {list.id === app.activeListId ? 'font-bold' : ''}"
          >
            {#if list.id === app.activeListId}
              <svg class="h-4 w-4 shrink-0 opacity-50" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" />
              </svg>
            {/if}
            <span>{list.title}</span>
          </button>
          <div class="relative shrink-0" data-list-menu>
            <button
              onclick={() => (listMenuId = listMenuId === list.id ? null : list.id)}
              class="rounded p-1 opacity-0 transition-opacity group-hover:opacity-40 hover:!opacity-80 {listMenuId === list.id ? '!opacity-80' : ''}"
            >
              <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
              </svg>
            </button>
            {#if listMenuId === list.id}
              <div class="absolute right-0 top-full z-40 mt-1 min-w-[140px] rounded-lg border border-border-light bg-surface-light py-1 shadow-lg dark:border-border-dark dark:bg-surface-dark">
                <button
                  onclick={() => handleDeleteList(list.id)}
                  class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-danger hover:bg-black/5 dark:hover:bg-white/10"
                >
                  <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  Delete
                </button>
              </div>
            {/if}
          </div>
        </div>
      {/each}

      <!-- New list inline -->
      <div class="px-2 mt-1">
        {#if showNewList}
          <div class="flex gap-2 px-1">
            <input
              type="text"
              bind:value={newListName}
              placeholder="List name"
              class="min-w-0 flex-1 rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-border-dark"
              onkeydown={(e) => { if (e.key === "Enter") handleNewList(); if (e.key === "Escape") { showNewList = false; newListName = ""; } }}
            />
            <button
              onclick={handleNewList}
              disabled={!newListName.trim()}
              class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white disabled:opacity-40"
            >
              Add
            </button>
          </div>
        {:else}
          <button
            onclick={() => (showNewList = true)}
            class="w-full rounded-lg px-3 py-2.5 text-left text-sm text-primary hover:bg-primary/5"
          >
            + New list
          </button>
        {/if}
      </div>
    </div>

    <!-- Footer: workspace switcher (left) + settings gear (right) -->
    <div class="flex items-center justify-between border-t border-border-light px-3 py-2 dark:border-border-dark">
      <!-- Workspace switcher (custom drop-up) -->
      <div class="relative min-w-0 flex-1" bind:this={workspacePickerEl}>
        <button
          onclick={() => (showWorkspacePicker = !showWorkspacePicker)}
          class="flex w-full items-center gap-1.5 rounded-lg px-2 py-1.5 text-sm opacity-60 hover:bg-black/5 hover:opacity-100 dark:hover:bg-white/10"
        >
          <svg class="h-3.5 w-3.5 shrink-0 transition-transform {showWorkspacePicker ? 'rotate-180' : ''}" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06-.02L10 8.832 6.29 12.77a.75.75 0 11-1.08-1.04l4.25-4.5a.75.75 0 011.08 0l4.25 4.5a.75.75 0 01-.02 1.06z" />
          </svg>
          <span class="truncate">{app.config?.current_workspace ?? "Workspace"}</span>
        </button>
        {#if showWorkspacePicker}
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="absolute bottom-full left-0 mb-1 w-full rounded-lg border border-border-light bg-surface-light py-1 shadow-lg dark:border-border-dark dark:bg-surface-dark"
          >
            {#each workspaceNames as name}
              {@const ws = app.config?.workspaces[name]}
              <div class="group flex items-center px-1 hover:bg-black/5 dark:hover:bg-white/10">
                <button
                  onclick={() => { app.switchWorkspace(name); showWorkspacePicker = false; }}
                  class="flex min-w-0 flex-1 items-center gap-2 px-2 py-1.5 text-left {name === app.config?.current_workspace ? 'font-bold' : ''}"
                >
                  {#if name === app.config?.current_workspace}
                    <svg class="h-4 w-4 shrink-0 opacity-50" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" />
                    </svg>
                  {/if}
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm">{name}</p>
                    <p class="truncate text-xs opacity-40">{ws?.path ?? ""}</p>
                  </div>
                </button>
                <div class="relative shrink-0" data-ws-menu>
                  <button
                    onclick={(e) => { e.stopPropagation(); wsMenuName = wsMenuName === name ? null : name; }}
                    class="rounded p-1 opacity-0 transition-opacity group-hover:opacity-40 hover:!opacity-80 {wsMenuName === name ? '!opacity-80' : ''}"
                  >
                    <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
                    </svg>
                  </button>
                  {#if wsMenuName === name}
                    <div class="absolute right-0 top-full z-40 mt-1 min-w-[140px] rounded-lg border border-border-light bg-surface-light py-1 shadow-lg dark:border-border-dark dark:bg-surface-dark">
                      <button
                        onclick={() => { wsMenuName = null; app.removeWorkspace(name); }}
                        class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-danger hover:bg-black/5 dark:hover:bg-white/10"
                      >
                        <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
                        </svg>
                        Delete
                      </button>
                    </div>
                  {/if}
                </div>
              </div>
            {/each}
            <div class="mt-1 border-t border-border-light px-1 pt-1 dark:border-border-dark">
              <button
                onclick={() => { showWorkspacePicker = false; app.setScreen("setup"); }}
                class="w-full rounded-md px-2 py-1.5 text-left text-sm text-primary hover:bg-primary/5"
              >
                + Add workspace
              </button>
            </div>
          </div>
        {/if}
      </div>

      <!-- Settings gear -->
      <button
        onclick={openSettings}
        class="rounded-lg p-2 hover:bg-black/5 dark:hover:bg-white/10"
        title="Settings"
      >
        <svg class="h-5 w-5 opacity-50 hover:opacity-80" viewBox="0 0 20 20" fill="currentColor">
          <path
            fill-rule="evenodd"
            d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z"
            clip-rule="evenodd"
          />
        </svg>
      </button>
    </div>
  </div>

  <!-- Main content panel -->
  <div class="relative flex h-full w-screen shrink-0 flex-col bg-surface-light dark:bg-surface-dark">
    <!-- Dim overlay when drawer is open -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="absolute inset-0 z-30 transition-opacity duration-250 ease-out {showDrawer ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}"
      style="box-shadow: inset 8px 0 24px rgba(0,0,0,0.4); background: rgba(0,0,0,0.4)"
      onclick={closeDrawer}
      onkeydown={(e) => { if (e.key === "Escape") closeDrawer(); }}
    ></div>
    <!-- Header -->
    <header
      class="relative flex items-center border-b border-border-light px-4 py-3 dark:border-border-dark"
    >
      <!-- Back arrow (left) -->
      <button
        onclick={() => (showDrawer = !showDrawer)}
        class="absolute left-2 rounded-lg p-1.5 hover:bg-black/5 dark:hover:bg-white/10"
      >
        <svg class="h-5 w-5 opacity-60" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" />
        </svg>
      </button>

      <!-- Centered title -->
      <div class="flex-1 text-center">
        <p class="text-xs text-text-secondary-light dark:text-text-secondary-dark">
          {app.config?.current_workspace ?? ""}
        </p>
        <p class="text-lg font-bold">{app.activeList?.title ?? "Tasks"}</p>
      </div>

      <!-- Sync spinner (right) -->
      {#if app.syncing}
        <div class="absolute right-4 h-5 w-5 animate-spin rounded-full border-2 border-primary border-t-transparent"></div>
      {/if}
    </header>

    <!-- Task list -->
    <main class="flex-1 overflow-y-auto">
      {#if app.lists.length === 0}
        <div class="flex h-full flex-col items-center justify-center p-8 text-center">
          <p class="text-lg font-medium opacity-60">No lists yet</p>
          <p class="mt-1 text-sm opacity-40">Tap the list name above to create one</p>
        </div>
      {:else if !app.activeListId}
        <div class="flex h-full items-center justify-center opacity-40">
          Select a list
        </div>
      {:else}
        {#each app.pendingTasks as task (task.id)}
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            draggable="true"
            ondragstart={(e) => handleDragStart(e, task.id)}
            ondragover={(e) => handleDragOver(e, task.id)}
            ondragend={handleDragEnd}
            ondrop={(e) => handleDrop(e, task.id)}
            class="{dragId === task.id ? 'opacity-30' : ''} {dragOverId === task.id && dragId !== task.id ? 'border-t-2 border-t-primary' : ''}"
          >
            <TaskItem {task} />
          </div>
        {/each}

        {#if app.pendingTasks.length === 0}
          <div class="p-8 text-center text-sm opacity-40">No tasks. Add one below.</div>
        {/if}

        {#if app.completedTasks.length > 0}
          <div class="h-4"></div>
          <button
            onclick={() => (showCompleted = !showCompleted)}
            class="flex w-full items-center justify-between border-t border-border-light px-4 py-3 text-sm font-medium text-text-secondary-light transition-colors hover:bg-black/5 dark:border-border-dark dark:text-text-secondary-dark dark:hover:bg-white/5"
          >
            Completed ({app.completedTasks.length})
            <svg
              class="h-4 w-4 transition-transform {showCompleted ? 'rotate-90' : ''}"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z"
              />
            </svg>
          </button>
          {#if showCompleted}
            {#each app.completedTasks as task (task.id)}
              <TaskItem {task} />
            {/each}
          {/if}
        {/if}
      {/if}
    </main>

    <!-- FAB button -->
    <div
      class="pointer-events-none absolute bottom-6 left-0 right-0 z-30 flex justify-center transition-all duration-250 ease-out {newTaskState.open ? 'opacity-0 scale-75' : ''} {showDrawer ? 'translate-y-24 opacity-0' : 'translate-y-0 opacity-100'}"
    >
      <button
        onclick={() => { if (app.activeListId) newTaskState.open = true; }}
        disabled={!app.activeListId}
        class="pointer-events-auto flex h-14 w-14 items-center justify-center rounded-full bg-primary text-white shadow-lg transition-transform hover:scale-105 active:scale-95 disabled:opacity-40 disabled:shadow-none"
      >
        <svg class="h-7 w-7" viewBox="0 0 20 20" fill="currentColor">
          <path d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" />
        </svg>
      </button>
    </div>
  </div>
</div>
</div>

<!-- Settings popup overlay -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="fixed inset-0 z-50 flex transition-opacity duration-200 {showSettings ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}"
  style="padding: 4%"
>
  <!-- Backdrop -->
  <div
    class="absolute inset-0 bg-black/50"
    onclick={closeSettings}
    onkeydown={(e) => { if (e.key === "Escape") closeSettings(); }}
  ></div>
  <!-- Settings card -->
  <div
    class="relative flex h-full w-full flex-col overflow-hidden rounded-2xl bg-surface-light transition-transform duration-200 dark:bg-surface-dark {showSettings ? 'scale-100' : 'scale-95'}"
    style="border: 1px solid rgba(255,255,255,0.1); box-shadow: 0 25px 60px rgba(0,0,0,0.7), 0 10px 20px rgba(0,0,0,0.5)"
  >
    <SettingsScreen onclose={closeSettings} />
  </div>
</div>

<!-- Toast overlay (outside sliding container so it stays centered) -->
<div class="pointer-events-none fixed inset-0 z-50">
  <NewTaskInput />
</div>
