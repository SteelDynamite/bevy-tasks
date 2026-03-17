<script lang="ts">
  import { app } from "../stores/app.svelte";

  let title = $state("");

  async function handleSubmit() {
    if (!title.trim()) return;
    await app.createTask(title.trim());
    title = "";
  }
</script>

<div
  class="border-t border-border-light bg-surface-light px-4 py-3 dark:border-border-dark dark:bg-surface-dark"
>
  <form
    onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}
    class="flex items-center gap-2"
  >
    <input
      type="text"
      bind:value={title}
      placeholder={app.activeListId ? "Add a task…" : "Select a list first"}
      disabled={!app.activeListId}
      class="min-w-0 flex-1 rounded-xl border border-border-light bg-card-light px-4 py-2.5 text-sm outline-none placeholder:opacity-40 focus:border-primary disabled:opacity-30 dark:border-border-dark dark:bg-card-dark"
    />
    <button
      type="submit"
      disabled={!title.trim() || !app.activeListId}
      class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary text-white shadow-md transition-transform hover:scale-105 active:scale-95 disabled:opacity-40 disabled:shadow-none"
    >
      <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <path d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" />
      </svg>
    </button>
  </form>
</div>
