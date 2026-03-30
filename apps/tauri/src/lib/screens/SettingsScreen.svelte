<script lang="ts">
  import { app } from "../stores/app.svelte";

  let { onclose }: { onclose?: () => void } = $props();

  let webdavUrl = $state("");
  let webdavUser = $state("");
  let webdavPass = $state("");
  let testStatus = $state<"idle" | "testing" | "ok" | "fail">("idle");

  async function testConnection() {
    testStatus = "testing";
    try {
      await (globalThis as any).__TAURI_INTERNALS__.invoke("test_webdav_connection", {
        url: webdavUrl,
        username: webdavUser,
        password: webdavPass,
      });
      testStatus = "ok";
    } catch {
      testStatus = "fail";
    }
  }

  async function saveWebdav() {
    if (!app.config?.current_workspace || !webdavUrl.trim()) return;
    await (globalThis as any).__TAURI_INTERNALS__.invoke("set_webdav_config", {
      workspaceName: app.config.current_workspace,
      webdavUrl: webdavUrl.trim(),
    });
    if (webdavUser && webdavPass) {
      const domain = new URL(webdavUrl).hostname;
      await (globalThis as any).__TAURI_INTERNALS__.invoke("store_credentials", {
        domain,
        username: webdavUser,
        password: webdavPass,
      });
    }
  }

</script>

<header
  class="flex items-center justify-between border-b border-border-light px-4 py-3 dark:border-border-dark"
>
  <h1 class="text-lg font-bold">Settings</h1>
  <button
    onclick={() => onclose?.()}
    class="rounded-lg p-1.5 hover:bg-black/5 dark:hover:bg-white/10"
  >
    <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
      <path
        d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z"
      />
    </svg>
  </button>
</header>

<main class="flex-1 overflow-y-auto p-4">
  <!-- WebDAV Sync -->
  <section class="mb-6">
    <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide opacity-50">
      WebDAV Sync
    </h2>
    <div class="rounded-xl border border-border-light p-4 dark:border-border-dark">
      <label class="mb-1 block text-xs font-medium opacity-60">Server URL</label>
      <input
        type="url"
        bind:value={webdavUrl}
        placeholder="https://dav.example.com/tasks/"
        class="mb-3 w-full rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-border-dark"
      />

      <label class="mb-1 block text-xs font-medium opacity-60">Username</label>
      <input
        type="text"
        bind:value={webdavUser}
        class="mb-3 w-full rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-border-dark"
      />

      <label class="mb-1 block text-xs font-medium opacity-60">Password</label>
      <input
        type="password"
        bind:value={webdavPass}
        class="mb-4 w-full rounded-lg border border-border-light bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-border-dark"
      />

      <div class="flex gap-2">
        <button
          onclick={testConnection}
          disabled={!webdavUrl.trim()}
          class="rounded-lg border border-border-light px-4 py-2 text-sm font-medium hover:bg-black/5 disabled:opacity-40 dark:border-border-dark dark:hover:bg-white/10"
        >
          {testStatus === "testing" ? "Testing…" : testStatus === "ok" ? "Connected" : testStatus === "fail" ? "Failed — Retry" : "Test Connection"}
        </button>
        <button
          onclick={saveWebdav}
          disabled={!webdavUrl.trim()}
          class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover disabled:opacity-40"
        >
          Save
        </button>
      </div>
    </div>

    {#if app.config?.current_workspace}
      <button
        onclick={() => app.triggerSync()}
        disabled={app.syncing}
        class="mt-3 w-full rounded-lg bg-primary py-2.5 text-sm font-medium text-white hover:bg-primary-hover disabled:opacity-40"
      >
        {app.syncing ? "Syncing…" : "Sync Now"}
      </button>
    {/if}
  </section>

  <!-- Theme -->
  <section>
    <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide opacity-50">
      Appearance
    </h2>
    <button
      onclick={() => app.toggleDarkMode()}
      class="flex w-full items-center justify-between rounded-xl border border-border-light p-4 dark:border-border-dark"
    >
      <span class="text-sm font-medium">Dark mode</span>
      <div
        class="h-6 w-11 rounded-full transition-colors {app.darkMode ? 'bg-primary' : 'bg-gray-300 dark:bg-gray-600'}"
      >
        <div
          class="h-5 w-5 translate-y-0.5 rounded-full bg-white shadow transition-transform {app.darkMode ? 'translate-x-5.5' : 'translate-x-0.5'}"
        ></div>
      </div>
    </button>
  </section>

  <p class="mt-8 text-center text-xs opacity-30">Tauri v2 + Svelte</p>
</main>
