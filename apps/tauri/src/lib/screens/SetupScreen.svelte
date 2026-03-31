<script lang="ts">
  import { open } from "@tauri-apps/plugin-dialog";
  import { app } from "../stores/app.svelte";

  let name = $state("");
  let path = $state("");

  async function pickFolder() {
    const selected = await open({ directory: true, multiple: false });
    if (selected) path = selected as string;
  }

  async function handleCreate() {
    if (!name.trim() || !path.trim()) return;
    await app.addWorkspace(name.trim(), path.trim());
  }
</script>

<div class="flex h-full items-center justify-center p-6">
  <div
    class="w-full max-w-sm rounded-2xl bg-card-light p-8 shadow-lg dark:bg-card-dark"
  >
    <h1 class="mb-1 text-2xl font-bold">Onyx</h1>
    <p class="mb-6 text-sm text-text-secondary-light dark:text-text-secondary-dark">
      Create or open a workspace to get started.
    </p>

    <label class="mb-1 block text-sm font-medium">
      Workspace name
      <input
        type="text"
        bind:value={name}
        placeholder="My Tasks"
        class="mt-1 mb-4 w-full rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm font-normal outline-none focus:border-primary dark:border-border-dark"
      />
    </label>

    <!-- svelte-ignore a11y_label_has_associated_control -->
    <label class="mb-1 block text-sm font-medium">Folder</label>
    <div class="mb-6 flex gap-2">
      <input
        type="text"
        bind:value={path}
        readonly
        placeholder="Select a folder…"
        class="min-w-0 flex-1 rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm dark:border-border-dark"
      />
      <button
        onclick={pickFolder}
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover"
      >
        Browse
      </button>
    </div>

    <button
      onclick={handleCreate}
      disabled={!name.trim() || !path.trim()}
      class="w-full rounded-lg bg-primary py-2.5 text-sm font-medium text-white hover:bg-primary-hover disabled:opacity-40"
    >
      Create Workspace
    </button>
  </div>
</div>
