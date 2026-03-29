<script lang="ts">
  import { app } from "../stores/app.svelte";
  import TaskItem from "../components/TaskItem.svelte";
  import NewTaskInput, { newTaskState } from "../components/NewTaskInput.svelte";
  import SettingsScreen from "./SettingsScreen.svelte";

  let showDrawer = $state(false);
  let showSettings = $state(false);
  let showNewList = $state(false);
  let newListName = $state("");
  let showCompleted = $state(true);
  let confirmDeleteList = $state<string | null>(null);
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
    showDrawer = false;
  }

  async function handleDeleteList(id: string) {
    await app.deleteList(id);
    confirmDeleteList = null;
    showDrawer = false;
  }

  function handleDragStart(e: DragEvent, taskId: string) {
    dragId = taskId;
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", taskId);
      // Create an unclipped drag image
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
    confirmDeleteList = null;
  }

  function openSettings() {
    showSettings = true;
    showDrawer = false;
  }

  function closeSettings() {
    showSettings = false;
  }

  let translateX = $derived(showDrawer ? '0' : showSettings ? '-160vw' : '-80vw');
</script>

<!-- Viewport clip -->
<div class="h-screen w-screen overflow-hidden">
<!-- Sliding container: left drawer + main content + settings panel move as one piece -->
<div
  class="flex h-full ease-out {resizing ? '' : 'transition-transform duration-250'}"
  style="width: calc(100vw + 160vw); transform: translateX({translateX})"
>
  <!-- Drawer panel (always rendered, sits to the left) -->
  <div class="flex h-full w-[80vw] shrink-0 flex-col bg-surface-light dark:bg-surface-dark">
    <!-- Drawer header -->
    <div class="border-b border-border-light px-4 py-4 dark:border-border-dark">
      <p class="text-xs text-text-secondary-light dark:text-text-secondary-dark">
        {app.config?.current_workspace ?? ""}
      </p>
      <h2 class="text-lg font-bold">Lists</h2>
    </div>

    <!-- List items -->
    <div class="flex-1 overflow-y-auto py-2">
      {#each app.lists as list (list.id)}
        <div class="flex items-center px-2">
          <button
            onclick={() => { app.selectList(list.id); closeDrawer(); }}
            class="flex-1 rounded-lg px-3 py-2.5 text-left text-sm hover:bg-black/5 dark:hover:bg-white/10 {list.id === app.activeListId ? 'font-bold text-primary bg-primary/5' : ''}"
          >
            {list.title}
          </button>
          {#if confirmDeleteList === list.id}
            <button
              onclick={() => handleDeleteList(list.id)}
              class="rounded px-2 py-1 text-xs font-medium text-danger hover:bg-danger/10"
            >
              Confirm
            </button>
            <button
              onclick={() => (confirmDeleteList = null)}
              class="rounded px-2 py-1 text-xs opacity-60 hover:opacity-100"
            >
              Cancel
            </button>
          {:else}
            <button
              onclick={() => (confirmDeleteList = list.id)}
              class="rounded p-1.5 opacity-30 hover:opacity-60"
              title="Delete list"
            >
              <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path
                  fill-rule="evenodd"
                  d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
          {/if}
        </div>
      {/each}
    </div>

    <!-- New list button at bottom -->
    <div class="border-t border-border-light px-2 py-2 dark:border-border-dark">
      {#if showNewList}
        <div class="flex gap-2 px-2">
          <input
            type="text"
            bind:value={newListName}
            placeholder="List name"
            class="min-w-0 flex-1 rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-border-dark"
            onkeydown={(e) => { if (e.key === "Enter") handleNewList(); }}
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

  <!-- Main content panel -->
  <div class="relative flex h-full w-screen shrink-0 flex-col bg-surface-light dark:bg-surface-dark">
    <!-- Dim overlay + shadow when drawer or settings is open -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="absolute inset-0 z-30 transition-opacity duration-250 ease-out {showDrawer || showSettings ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}"
      style="box-shadow: {showDrawer ? 'inset 8px 0 24px rgba(0,0,0,0.4)' : showSettings ? 'inset -8px 0 24px rgba(0,0,0,0.4)' : 'none'}; background: rgba(0,0,0,0.4)"
      onclick={() => { if (showDrawer) closeDrawer(); if (showSettings) closeSettings(); }}
      onkeydown={(e) => { if (e.key === "Escape") { closeDrawer(); closeSettings(); } }}
    ></div>
    <!-- Header -->
    <header
      class="flex items-center justify-between border-b border-border-light px-4 py-3 dark:border-border-dark"
    >
      <div class="min-w-0 flex-1">
        <p class="text-xs text-text-secondary-light dark:text-text-secondary-dark">
          {app.config?.current_workspace ?? ""}
        </p>
        <button
          onclick={() => (showDrawer = !showDrawer)}
          class="flex items-center gap-1 text-lg font-bold"
        >
          {app.activeList?.title ?? "Tasks"}
          <svg class="h-4 w-4 opacity-50 transition-transform {showDrawer ? 'rotate-180' : ''}" viewBox="0 0 20 20" fill="currentColor">
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
            />
          </svg>
        </button>
      </div>

      <div class="flex items-center gap-2">
        {#if app.syncing}
          <div class="h-5 w-5 animate-spin rounded-full border-2 border-primary border-t-transparent"></div>
        {/if}
        <button
          onclick={openSettings}
          class="rounded-lg p-2 hover:bg-black/5 dark:hover:bg-white/10"
          title="Settings"
        >
          <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path
              fill-rule="evenodd"
              d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
      </div>
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
            class="transition-all duration-150 {dragId === task.id ? 'opacity-30' : ''} {dragOverId === task.id && dragId !== task.id ? 'border-t-2 border-t-primary' : ''}"
          >
            <TaskItem {task} />
          </div>
        {/each}

        {#if app.pendingTasks.length === 0}
          <div class="p-8 text-center text-sm opacity-40">No tasks. Add one below.</div>
        {/if}

        {#if app.completedTasks.length > 0}
          <button
            onclick={() => (showCompleted = !showCompleted)}
            class="flex w-full items-center gap-2 border-t border-border-light px-4 py-3 text-sm font-medium text-text-secondary-light dark:border-border-dark dark:text-text-secondary-dark"
          >
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
            Completed ({app.completedTasks.length})
          </button>
          {#if showCompleted}
            {#each app.completedTasks as task (task.id)}
              <TaskItem {task} />
            {/each}
          {/if}
        {/if}
      {/if}
    </main>

    <!-- FAB button, slides with main content -->
    <div
      class="pointer-events-none absolute bottom-6 left-0 right-0 z-30 flex justify-center transition-all duration-250 ease-out {newTaskState.open ? 'opacity-0 scale-75' : ''} {showDrawer || showSettings ? 'translate-y-24 opacity-0' : 'translate-y-0 opacity-100'}"
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

  <!-- Settings panel (sits to the right of main content) -->
  <div class="flex h-full w-[80vw] shrink-0 flex-col bg-surface-light dark:bg-surface-dark">
    <SettingsScreen onclose={closeSettings} />
  </div>
</div>
</div>

<!-- Toast overlay (outside sliding container so it stays centered) -->
<div class="pointer-events-none fixed inset-0 z-50">
  <NewTaskInput />
</div>
