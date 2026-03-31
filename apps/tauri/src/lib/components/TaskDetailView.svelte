<script lang="ts">
  import type { Task } from "../types";
  import { app } from "../stores/app.svelte";
  import DateTimePicker from "./DateTimePicker.svelte";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import { platform } from "@tauri-apps/plugin-os";

  const appWindow = getCurrentWindow();
  const currentPlatform = platform();
  const isDesktop = currentPlatform === "linux" || currentPlatform === "windows";

  let { task, onback }: { task: Task; onback: () => void } = $props();

  let title = $state(task.title);
  let description = $state(task.description);
  let showMenu = $state(false);
  let showMoveSubmenu = $state(false);
  let menuEl = $state<HTMLDivElement | null>(null);
  let showDatePicker = $state(false);
  let saveTimer: ReturnType<typeof setTimeout>;

  let otherLists = $derived(app.lists.filter((l) => l.id !== app.activeListId));

  function handleHeaderMouseDown(e: MouseEvent) {
    if (e.button !== 0) return;
    if ((e.target as HTMLElement).closest("button")) return;
    if (isDesktop) appWindow.startDragging();
  }

  function debouncedSave(fields: Partial<Task>) {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      app.updateTask({ ...task, ...fields, updated_at: new Date().toISOString() });
    }, 400);
  }

  function handleTitleInput() {
    debouncedSave({ title: title.trim() || task.title });
  }

  function handleDescInput() {
    debouncedSave({ description });
  }

  function handleDateChange(iso: string | null) {
    app.updateTask({ ...task, due_date: iso, updated_at: new Date().toISOString() });
  }

  async function handleToggle() {
    await app.toggleTask(task.id);
    onback();
  }

  async function handleDelete() {
    showMenu = false;
    if (!confirm(`Delete task "${task.title}"?`)) return;
    await app.deleteTask(task.id);
    onback();
  }

  function handleMenuClickOutside(e: MouseEvent) {
    if (showMenu && menuEl && !menuEl.contains(e.target as Node)) {
      showMenu = false;
    }
  }

  $effect(() => {
    if (showMenu) {
      window.addEventListener("mousedown", handleMenuClickOutside);
      return () => window.removeEventListener("mousedown", handleMenuClickOutside);
    }
  });

  let isCompleted = $derived(task.status === "completed");

  function formatDateChip(iso: string): string {
    const d = new Date(iso);
    const today = new Date();
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const day = dayNames[d.getDay()];
    const pad = (n: number) => String(n).padStart(2, "0");
    const hasTime = d.getHours() !== 0 || d.getMinutes() !== 0;
    const timePart = hasTime ? `, ${pad(d.getHours())}:${pad(d.getMinutes())}` : "";
    if (d.toDateString() === today.toDateString()) return `Today${timePart}`;
    return `${day}, ${pad(d.getDate())}/${pad(d.getMonth() + 1)}${timePart}`;
  }
</script>

<!-- Header -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<header
  onmousedown={handleHeaderMouseDown}
  class="flex h-11 items-center border-b border-border-light px-4 dark:border-border-dark"
>
  <button
    onclick={onback}
    class="rounded-lg p-1.5 hover:bg-black/5 dark:hover:bg-white/10"
  >
    <svg class="h-5 w-5 opacity-60" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" />
    </svg>
  </button>
</header>

<!-- Content -->
<main class="relative flex-1 overflow-y-auto px-4 pt-4">
  <!-- Kebab menu -->
  <div class="absolute right-3 top-2" bind:this={menuEl}>
    <button
      onclick={() => (showMenu = !showMenu)}
      class="rounded-lg p-1.5 opacity-50 hover:bg-black/5 hover:opacity-80 dark:hover:bg-white/10"
    >
      <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
      </svg>
    </button>
    {#if showMenu}
      <div class="absolute right-0 top-full z-40 mt-1 min-w-[200px] rounded-lg border border-border-light bg-surface-light py-1 shadow-lg dark:border-border-dark dark:bg-surface-dark">
        <button
          onclick={handleToggle}
          class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-black/5 dark:hover:bg-white/10"
        >
          <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
            {#if isCompleted}
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            {:else}
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            {/if}
          </svg>
          {isCompleted ? "Restore task" : "Mark as completed"}
        </button>
        {#if otherLists.length > 0}
          <div class="relative">
            <button
              onclick={() => (showMoveSubmenu = !showMoveSubmenu)}
              class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-black/5 dark:hover:bg-white/10"
            >
              <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path d="M2 6a2 2 0 012-2h5l2 2h5a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" />
              </svg>
              Move to...
              <svg class="ml-auto h-3 w-3 opacity-40" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" />
              </svg>
            </button>
            {#if showMoveSubmenu}
              <div class="absolute left-full top-0 z-50 ml-1 min-w-[160px] rounded-lg border border-border-light bg-surface-light py-1 shadow-lg dark:border-border-dark dark:bg-surface-dark">
                {#each otherLists as list}
                  <button
                    onclick={async () => { showMenu = false; showMoveSubmenu = false; await app.moveTask(task.id, list.id); onback(); }}
                    class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-black/5 dark:hover:bg-white/10"
                  >
                    {list.title}
                  </button>
                {/each}
              </div>
            {/if}
          </div>
        {/if}
        <button
          onclick={handleDelete}
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
  <!-- Title -->
  <input
    type="text"
    bind:value={title}
    oninput={handleTitleInput}
    placeholder="Task title"
    class="w-full bg-transparent text-xl font-bold outline-none placeholder:opacity-30"
  />

  <!-- Description -->
  <div class="mt-4 flex items-start gap-3">
    <svg class="mt-0.5 h-5 w-5 shrink-0 opacity-40" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M4 4a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zm0 4a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zm0 4a1 1 0 011-1h7a1 1 0 110 2H5a1 1 0 01-1-1z" />
    </svg>
    <textarea
      bind:value={description}
      oninput={handleDescInput}
      placeholder="Add details"
      rows="3"
      class="w-full flex-1 resize-none bg-transparent text-sm outline-none placeholder:opacity-40"
    ></textarea>
  </div>

  <!-- Date/time -->
  <div class="mt-4 flex items-center gap-3">
    <svg class="h-5 w-5 shrink-0 opacity-40" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
    </svg>
    {#if task.due_date}
      <div class="flex items-center gap-1.5 rounded-full border border-border-light bg-black/5 px-3 py-1 text-sm dark:border-border-dark dark:bg-white/10">
        <button onclick={() => (showDatePicker = true)} class="hover:opacity-70">
          {formatDateChip(task.due_date)}
        </button>
        <button onclick={() => handleDateChange(null)} class="opacity-40 hover:opacity-80">
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor">
            <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
          </svg>
        </button>
      </div>
    {:else}
      <button
        onclick={() => (showDatePicker = true)}
        class="text-sm opacity-40 hover:opacity-70"
      >
        Add date/time
      </button>
    {/if}
  </div>
</main>

<!-- Date picker overlay -->
{#if showDatePicker}
  <DateTimePicker
    value={task.due_date}
    onchange={handleDateChange}
    onclose={() => (showDatePicker = false)}
  />
{/if}
