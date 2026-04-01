<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { app } from "../stores/app.svelte";

  let { onclose }: { onclose?: () => void } = $props();

  let webdavUrl = $state("");
  let webdavUser = $state("");
  let webdavPass = $state("");
  let testStatus = $state<"idle" | "testing" | "ok" | "fail">("idle");

  $effect(() => {
    const ws = app.config?.current_workspace;
    if (!ws) return;
    const cfg = app.config?.workspaces[ws];
    if (cfg?.webdav_url) {
      webdavUrl = cfg.webdav_url;
      try {
        const domain = new URL(cfg.webdav_url).hostname;
        invoke<[string, string]>("load_credentials", { domain }).then(([u, p]) => {
          webdavUser = u;
          webdavPass = p;
        }).catch(() => {});
      } catch {}
    }
  });

  async function testConnection() {
    testStatus = "testing";
    try {
      await invoke("test_webdav_connection", {
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
    await invoke("set_webdav_config", {
      workspaceName: app.config.current_workspace,
      webdavUrl: webdavUrl.trim(),
    });
    if (webdavUser && webdavPass) {
      const domain = new URL(webdavUrl).hostname;
      await invoke("store_credentials", {
        domain,
        username: webdavUser,
        password: webdavPass,
      });
    }
    await app.loadConfig();
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
      <div class="mt-3 flex items-center gap-2">
        <select
          value={app.syncMode}
          onchange={(e) => app.setSyncMode((e.target as HTMLSelectElement).value as "full" | "push" | "pull")}
          class="appearance-none rounded-lg border border-border-light bg-surface-light px-3 py-2 text-sm text-text-light outline-none focus:border-primary dark:border-border-dark dark:bg-surface-dark dark:text-text-dark"
        >
          <option value="full">Sync both ways</option>
          <option value="push">Push only</option>
          <option value="pull">Pull only</option>
        </select>
        <button
          onclick={() => app.triggerSync()}
          disabled={app.syncing}
          class="flex-1 rounded-lg bg-primary py-2 text-sm font-medium text-white hover:bg-primary-hover disabled:opacity-40"
        >
          {app.syncing ? "Syncing…" : "Sync Now"}
        </button>
      </div>
      {#if app.config.workspaces[app.config.current_workspace]?.last_sync}
        {@const lastSync = new Date(app.config.workspaces[app.config.current_workspace].last_sync!)}
        {@const secsAgo = Math.floor((Date.now() - lastSync.getTime()) / 1000)}
        {@const relTime = secsAgo < 60 ? "just now" : secsAgo < 3600 ? `${Math.floor(secsAgo / 60)}m ago` : `${Math.floor(secsAgo / 3600)}h ago`}
        <p class="mt-1.5 text-xs opacity-40">
          Last sync: {relTime}
          {#if app.lastSyncResult}
            &nbsp;·&nbsp;↑{app.lastSyncResult.uploaded} ↓{app.lastSyncResult.downloaded}
          {/if}
        </p>
      {/if}
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
