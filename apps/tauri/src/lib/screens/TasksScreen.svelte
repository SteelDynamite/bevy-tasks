<script lang="ts">
  import { app } from "../stores/app.svelte";
  import TaskItem from "../components/TaskItem.svelte";
  import BottomSheet from "../components/BottomSheet.svelte";
  import NewTaskInput from "../components/NewTaskInput.svelte";

  let showListSheet = $state(false);
  let showNewList = $state(false);
  let newListName = $state("");
  let showCompleted = $state(true);
  let confirmDeleteList = $state<string | null>(null);

  async function handleNewList() {
    if (!newListName.trim()) return;
    await app.createList(newListName.trim());
    newListName = "";
    showNewList = false;
    showListSheet = false;
  }

  async function handleDeleteList(id: string) {
    await app.deleteList(id);
    confirmDeleteList = null;
    showListSheet = false;
  }
</script>

<!-- Header -->
<header
  class="flex items-center justify-between border-b border-border-light px-4 py-3 dark:border-border-dark"
>
  <div class="min-w-0 flex-1">
    <button
      onclick={() => (showListSheet = true)}
      class="flex items-center gap-1 text-lg font-bold"
    >
      {app.activeList?.title ?? "Tasks"}
      <svg class="h-4 w-4 opacity-50" viewBox="0 0 20 20" fill="currentColor">
        <path
          fill-rule="evenodd"
          d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
        />
      </svg>
    </button>
    <p class="text-xs text-text-secondary-light dark:text-text-secondary-dark">
      {app.config?.current_workspace ?? ""}
    </p>
  </div>

  <div class="flex items-center gap-2">
    {#if app.syncing}
      <div class="h-5 w-5 animate-spin rounded-full border-2 border-primary border-t-transparent"></div>
    {/if}
    <button
      onclick={() => app.toggleDarkMode()}
      class="rounded-lg p-2 hover:bg-black/5 dark:hover:bg-white/10"
      title="Toggle theme"
    >
      {#if app.darkMode}
        <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
          <path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" />
        </svg>
      {:else}
        <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
          <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
        </svg>
      {/if}
    </button>
    <button
      onclick={() => app.setScreen("settings")}
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
<main class="flex-1 overflow-y-auto" style="height: calc(100vh - 57px - 72px)">
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
    <!-- Pending tasks -->
    {#each app.pendingTasks as task (task.id)}
      <TaskItem {task} />
    {/each}

    {#if app.pendingTasks.length === 0}
      <div class="p-8 text-center text-sm opacity-40">No tasks. Add one below.</div>
    {/if}

    <!-- Completed section -->
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

<!-- New task input (bottom bar) -->
<NewTaskInput />

<!-- List picker bottom sheet -->
{#if showListSheet}
  <BottomSheet onclose={() => { showListSheet = false; showNewList = false; }}>
    <div class="px-4 pb-2 pt-4">
      <h2 class="mb-3 text-lg font-bold">Lists</h2>
      {#each app.lists as list (list.id)}
        <div class="flex items-center">
          <button
            onclick={() => { app.selectList(list.id); showListSheet = false; }}
            class="flex-1 rounded-lg px-3 py-2.5 text-left text-sm hover:bg-black/5 dark:hover:bg-white/10 {list.id === app.activeListId ? 'font-bold text-primary' : ''}"
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

      {#if showNewList}
        <div class="mt-2 flex gap-2">
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
          class="mt-2 w-full rounded-lg px-3 py-2.5 text-left text-sm text-primary hover:bg-primary/5"
        >
          + New list
        </button>
      {/if}
    </div>
  </BottomSheet>
{/if}
