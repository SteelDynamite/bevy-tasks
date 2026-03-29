<script lang="ts" module>
  // Shared state accessible from outside
  export const newTaskState = $state({ open: false });
</script>

<script lang="ts">
  import { app } from "../stores/app.svelte";

  let title = $state("");
  let description = $state("");
  let inputEl = $state<HTMLInputElement | null>(null);

  async function handleSubmit() {
    if (!title.trim()) return;
    await app.createTask(title.trim(), description.trim() || undefined);
    title = "";
    description = "";
    newTaskState.open = false;
  }

  function handleClose() {
    newTaskState.open = false;
    title = "";
    description = "";
  }

  $effect(() => {
    if (newTaskState.open) {
      requestAnimationFrame(() => inputEl?.focus());
    }
  });
</script>

<!-- Backdrop -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="absolute inset-0 z-40 transition-opacity duration-250 ease-out {newTaskState.open ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'}"
  style="background: rgba(0,0,0,0.4)"
  onclick={handleClose}
  onkeydown={(e) => { if (e.key === "Escape") handleClose(); }}
></div>

<!-- Toast input sheet -->
<div
  class="pointer-events-auto absolute bottom-0 left-0 right-0 z-50 rounded-t-2xl bg-surface-light shadow-xl transition-all duration-250 ease-out dark:bg-card-dark {newTaskState.open ? 'translate-y-0 opacity-100' : 'translate-y-full opacity-0 pointer-events-none'}"
>
  <div class="px-4 pb-4 pt-3">
    <form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
      <input
        bind:this={inputEl}
        type="text"
        bind:value={title}
        placeholder="New task"
        class="w-full border-none bg-transparent text-base font-medium outline-none placeholder:opacity-40"
        onkeydown={(e) => { if (e.key === "Escape") handleClose(); }}
      />
      <input
        type="text"
        bind:value={description}
        placeholder="Add details"
        class="mt-2 w-full border-none bg-transparent text-sm outline-none placeholder:opacity-40"
        onkeydown={(e) => { if (e.key === "Escape") handleClose(); }}
      />
    </form>

    <div class="mt-3 flex items-center justify-between">
      <button class="opacity-40 hover:opacity-70" title="Set due date">
        <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
        </svg>
      </button>
      <button
        onclick={handleSubmit}
        disabled={!title.trim()}
        class="text-sm font-medium text-primary disabled:opacity-30"
      >
        Save
      </button>
    </div>
  </div>
</div>
