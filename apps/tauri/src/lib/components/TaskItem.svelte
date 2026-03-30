<script lang="ts" module>
  export const animateInIds = new Set<string>();
</script>

<script lang="ts">
  import type { Task } from "../types";
  import { app } from "../stores/app.svelte";

  let { task, onopen }: { task: Task; onopen?: (task: Task) => void } = $props();

  let touchStartX = $state(0);
  let swipeX = $state(0);
  let swiping = $state(false);
  let transitioning = $state(false);
  let animatingIn = $state(false);

  let isCompleted = $derived(task.status === "completed");

  $effect(() => {
    const _ = task.status;
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

  async function handleToggle(e: MouseEvent) {
    e.stopPropagation();
    transitioning = true;
    animateInIds.add(task.id);
    await new Promise((r) => setTimeout(r, 200));
    await app.toggleTask(task.id);
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
      transitioning = true;
      animateInIds.add(task.id);
      setTimeout(() => app.toggleTask(task.id), 200);
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
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="relative"
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
  <button
    class="group flex w-full items-start gap-3 bg-surface-light px-4 py-3 text-left hover:bg-black/5 dark:bg-surface-dark dark:hover:bg-white/5"
    style="transform: translateX({swipeX}px); transition: {swiping ? 'none' : 'transform 0.2s ease-out'}"
    onclick={() => onopen?.(task)}
  >
    <!-- Checkbox -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      onclick={handleToggle}
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
    </div>

    <!-- Content -->
    <div class="min-w-0 flex-1">
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
    </div>

    <!-- Chevron -->
    <svg class="mt-1 h-4 w-4 shrink-0 opacity-0 transition-opacity group-hover:opacity-30" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" />
    </svg>
  </button>
</div>
</div>
</div>
