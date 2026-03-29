<script lang="ts" module>
  let editingTaskId = $state<string | null>(null);
  export const animateInIds = new Set<string>();
</script>

<script lang="ts">
  import type { Task } from "../types";
  import { app } from "../stores/app.svelte";

  let { task }: { task: Task } = $props();

  let editTitle = $state(task.title);
  let editDesc = $state(task.description);
  let editing = $derived(editingTaskId === task.id);
  let touchStartX = $state(0);
  let swipeX = $state(0);
  let swiping = $state(false);
  let containerEl = $state<HTMLDivElement | null>(null);
  let titleInputEl = $state<HTMLInputElement | null>(null);
  let showMenu = $state(false);
  let menuEl = $state<HTMLDivElement | null>(null);
  let transitioning = $state(false);
  let animatingIn = $state(false);

  let isCompleted = $derived(task.status === "completed");

  $effect(() => {
    // Check on status change whether this task should animate in
    const _ = task.status; // track reactively
    if (animateInIds.has(task.id)) {
      animateInIds.delete(task.id);
      animatingIn = true;
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          animatingIn = false;
        });
      });
    }
  });

  async function handleToggle() {
    transitioning = true;
    animateInIds.add(task.id);
    await new Promise((r) => setTimeout(r, 200));
    await app.toggleTask(task.id);
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

  function startEditing() {
    if (editing) return;
    editingTaskId = task.id;
    editTitle = task.title;
    editDesc = task.description;
    setTimeout(() => titleInputEl?.focus(), 220);
  }

  async function save() {
    if (editingTaskId !== task.id) return;
    editingTaskId = null;
    const trimmed = editTitle.trim();
    if (!trimmed) { editTitle = task.title; return; }
    if (trimmed === task.title && editDesc === task.description) return;
    await app.updateTask({ ...task, title: trimmed, description: editDesc });
  }

  function handleFocusOut(e: FocusEvent) {
    if (containerEl?.contains(e.relatedTarget as Node)) return;
    requestAnimationFrame(() => {
      if (editingTaskId === task.id) save();
    });
  }

  function handleTouchStart(e: TouchEvent) {
    touchStartX = e.touches[0].clientX;
    swiping = true;
  }

  function handleTouchMove(e: TouchEvent) {
    if (!swiping) return;
    const dx = e.touches[0].clientX - touchStartX;
    if (isCompleted) swipeX = Math.max(0, dx);
    else swipeX = Math.min(0, dx);
  }

  function handleTouchEnd() {
    if (Math.abs(swipeX) > 100) {
      swipeX = 0;
      swiping = false;
      handleToggle();
      return;
    }
    swipeX = 0;
    swiping = false;
  }

  function formatDate(iso: string): string {
    const d = new Date(iso);
    const today = new Date();
    if (d.toDateString() === today.toDateString()) return "Today";
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);
    if (d.toDateString() === tomorrow.toDateString()) return "Tomorrow";
    return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  }
</script>

<div
  class="grid transition-[grid-template-rows,opacity] duration-300 ease-out {animatingIn || transitioning ? 'grid-rows-[0fr] opacity-0' : 'grid-rows-[1fr] opacity-100'}"
>
<div class="overflow-hidden">
<div
  bind:this={containerEl}
  class="relative {showMenu ? 'z-40' : ''}"
  ontouchstart={handleTouchStart}
  ontouchmove={handleTouchMove}
  ontouchend={handleTouchEnd}
>
  <!-- Swipe background -->
  {#if swipeX !== 0}
    <div
      class="absolute inset-0 flex items-center {swipeX < 0 ? 'justify-end' : 'justify-start'} bg-primary px-4 text-white"
    >
      <span class="text-sm font-medium">
        {isCompleted ? "Undo" : "Complete"}
      </span>
    </div>
  {/if}

  <!-- Task content -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="group relative flex items-start gap-3 bg-surface-light px-4 py-3 hover:bg-black/5 dark:bg-surface-dark dark:hover:bg-white/5"
    style="transform: translateX({swipeX}px); transition: {swiping ? 'none' : 'transform 0.2s ease-out'}"
    onmousedown={startEditing}
  >
    <!-- Checkbox -->
    <button
      onmousedown={(e) => { e.stopPropagation(); handleToggle(); }}
      class="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 transition-colors {isCompleted
        ? 'border-primary bg-primary'
        : 'border-gray-400 dark:border-gray-500'}"
    >
      {#if isCompleted}
        <svg class="h-3 w-3 text-white" viewBox="0 0 20 20" fill="currentColor">
          <path
            fill-rule="evenodd"
            d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
          />
        </svg>
      {/if}
    </button>

    <!-- Content -->
    <div class="min-w-0 flex-1" onfocusout={handleFocusOut}>
      {#if editing}
        <input
          type="text"
          bind:this={titleInputEl}
          bind:value={editTitle}
          class="w-full bg-transparent text-sm font-medium outline-none"
          onkeydown={(e) => { if (e.key === "Enter") (e.target as HTMLElement).blur(); if (e.key === "Escape") { editTitle = task.title; editDesc = task.description; editingTaskId = null; } }}
        />
      {:else}
        <p class="text-sm {isCompleted ? 'line-through opacity-50' : 'font-medium'}">
          {task.title}
        </p>
        {#if task.description}
          <p class="mt-0.5 text-xs opacity-40 line-clamp-1">{task.description}</p>
        {/if}
        {#if task.due_date}
          <span class="mt-1 inline-block rounded-full border border-border-light px-2 py-0.5 text-xs opacity-50 dark:border-border-dark">
            {formatDate(task.due_date)}
          </span>
        {/if}
      {/if}

      <!-- Expandable edit description -->
      <div class="grid transition-[grid-template-rows,opacity] duration-200 ease-out {editing ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'}">
        <div class="overflow-hidden">
          <textarea
            bind:value={editDesc}
            placeholder="Add description…"
            rows="2"
            class="mt-1 w-full resize-none bg-transparent text-xs opacity-60 outline-none"
            tabindex={editing ? 0 : -1}
            onkeydown={(e) => { if (e.key === "Escape") { editTitle = task.title; editDesc = task.description; editingTaskId = null; } }}
          ></textarea>
        </div>
      </div>
    </div>

    <!-- Kebab menu -->
      <div class="relative shrink-0" bind:this={menuEl}>
        <button
          onmousedown={(e) => { e.stopPropagation(); showMenu = !showMenu; }}
          class="rounded p-1 opacity-0 transition-opacity group-hover:opacity-40 hover:!opacity-80 {showMenu || editing ? '!opacity-40' : ''}"
          title="More"
        >
          <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
            <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
          </svg>
        </button>
        {#if showMenu}
          <div class="absolute right-0 top-full z-40 mt-1 min-w-[140px] rounded-lg border border-border-light bg-surface-light py-1 shadow-lg dark:border-border-dark dark:bg-surface-dark">
            <button
              onmousedown={(e) => { e.stopPropagation(); showMenu = false; app.deleteTask(task.id); }}
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
</div>
</div>
</div>
