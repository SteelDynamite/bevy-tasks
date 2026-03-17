<script lang="ts">
  import type { Task } from "../types";
  import { app } from "../stores/app.svelte";

  let { task }: { task: Task } = $props();

  let editing = $state(false);
  let editTitle = $state(task.title);
  let editDesc = $state(task.description);
  let touchStartX = $state(0);
  let swipeX = $state(0);
  let swiping = $state(false);

  let isCompleted = $derived(task.status === "completed");

  function handleTouchStart(e: TouchEvent) {
    touchStartX = e.touches[0].clientX;
    swiping = true;
  }

  function handleTouchMove(e: TouchEvent) {
    if (!swiping) return;
    const dx = e.touches[0].clientX - touchStartX;
    // Only allow left swipe for pending, right swipe for completed
    if (isCompleted) swipeX = Math.max(0, dx);
    else swipeX = Math.min(0, dx);
  }

  function handleTouchEnd() {
    if (Math.abs(swipeX) > 100) {
      app.toggleTask(task.id);
    }
    swipeX = 0;
    swiping = false;
  }

  async function saveEdit() {
    if (!editTitle.trim()) return;
    const updated = { ...task, title: editTitle.trim(), description: editDesc };
    await app.updateTask(updated);
    editing = false;
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
  class="relative overflow-hidden border-b border-border-light dark:border-border-dark"
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
  <div
    class="relative flex items-start gap-3 bg-surface-light px-4 py-3 dark:bg-surface-dark"
    style="transform: translateX({swipeX}px); transition: {swiping ? 'none' : 'transform 0.2s ease-out'}"
  >
    <!-- Checkbox -->
    <button
      onclick={() => app.toggleTask(task.id)}
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
    {#if editing}
      <div class="min-w-0 flex-1">
        <input
          type="text"
          bind:value={editTitle}
          class="w-full bg-transparent text-sm font-medium outline-none"
          onkeydown={(e) => { if (e.key === "Enter") saveEdit(); if (e.key === "Escape") editing = false; }}
        />
        <textarea
          bind:value={editDesc}
          placeholder="Add description…"
          rows="2"
          class="mt-1 w-full resize-none bg-transparent text-xs opacity-60 outline-none"
        />
        <div class="mt-1 flex gap-2">
          <button
            onclick={saveEdit}
            class="rounded px-2 py-1 text-xs font-medium text-primary"
          >
            Save
          </button>
          <button
            onclick={() => (editing = false)}
            class="rounded px-2 py-1 text-xs opacity-60"
          >
            Cancel
          </button>
        </div>
      </div>
    {:else}
      <button
        onclick={() => { editing = true; editTitle = task.title; editDesc = task.description; }}
        class="min-w-0 flex-1 text-left"
      >
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
      </button>
    {/if}

    <!-- Delete -->
    {#if !editing}
      <button
        onclick={() => app.deleteTask(task.id)}
        class="shrink-0 rounded p-1 opacity-0 transition-opacity hover:opacity-60 group-hover:opacity-30"
        style="opacity: 0.15"
        title="Delete"
      >
        <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
          <path
            fill-rule="evenodd"
            d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
            clip-rule="evenodd"
          />
        </svg>
      </button>
    {/if}
  </div>
</div>
