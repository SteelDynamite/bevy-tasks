<script lang="ts">
  import { open } from "@tauri-apps/plugin-dialog";
  import { app } from "../stores/app.svelte";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import { platform } from "@tauri-apps/plugin-os";

  const appWindow = getCurrentWindow();
  const currentPlatform = platform();
  const isDesktop = currentPlatform === "linux" || currentPlatform === "windows";
  const isWindows = currentPlatform === "windows";

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

  async function handleOpen() {
    const selected = await open({ directory: true, multiple: false });
    if (!selected) return;
    const folder = selected as string;
    // Derive workspace name from folder name
    const parts = folder.replace(/\\/g, "/").split("/");
    const wsName = parts[parts.length - 1] || "workspace";
    await app.addWorkspace(wsName, folder);
  }

  function handleDrag(e: MouseEvent) {
    if (e.button !== 0) return;
    if ((e.target as HTMLElement).closest("button, input")) return;
    if (isDesktop) appWindow.startDragging();
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="flex h-full flex-col" onmousedown={handleDrag}>
  <!-- Title bar area with window controls -->
  <header class="flex h-11 shrink-0 items-center justify-end px-2">
    {#if isDesktop}
      <div class="flex items-center gap-0.5">
        {#if isWindows}
          <button
            onclick={() => appWindow.minimize()}
            class="rounded p-1.5 opacity-50 hover:bg-black/10 hover:opacity-80 dark:hover:bg-white/10"
          >
            <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor">
              <path d="M4 10a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1z" />
            </svg>
          </button>
        {/if}
        <button
          onclick={() => appWindow.close()}
          class="rounded p-1.5 opacity-50 hover:bg-danger/20 hover:opacity-100 hover:text-danger dark:hover:bg-danger/20"
        >
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor">
            <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
          </svg>
        </button>
      </div>
    {/if}
  </header>

  <div class="flex flex-1 items-center justify-center p-6">
    <div
      class="w-full max-w-sm rounded-2xl bg-card-light p-8 shadow-lg dark:bg-card-dark"
    >
      <h1 class="mb-1 text-2xl font-bold">Onyx</h1>
      <p class="mb-6 text-sm text-text-secondary-light dark:text-text-secondary-dark">
        Create a new workspace or open an existing one.
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

      <div class="my-4 flex items-center gap-3">
        <div class="h-px flex-1 bg-border-light dark:bg-border-dark"></div>
        <span class="text-xs opacity-40">or</span>
        <div class="h-px flex-1 bg-border-light dark:bg-border-dark"></div>
      </div>

      <button
        onclick={handleOpen}
        class="w-full rounded-lg border border-border-light py-2.5 text-sm font-medium hover:bg-black/5 dark:border-border-dark dark:hover:bg-white/10"
      >
        Open Existing Folder
      </button>
    </div>
  </div>
</div>
