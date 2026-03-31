<script lang="ts">
  import { onMount } from "svelte";
  import { platform } from "@tauri-apps/plugin-os";
  import { app } from "./lib/stores/app.svelte";
  import SetupScreen from "./lib/screens/SetupScreen.svelte";
  import TasksScreen from "./lib/screens/TasksScreen.svelte";

  const isLinux = platform() === "linux";

  onMount(() => {
    app.loadConfig();
  });
</script>

<div class={app.darkMode ? "dark" : ""}>
  <div class="h-screen w-screen" class:p-2={isLinux}>
    <div
      class="relative h-full w-full overflow-hidden bg-surface-light text-text-light dark:bg-surface-dark dark:text-text-dark"
      class:rounded-xl={isLinux}
      class:linux-window-border={isLinux}
      style="container-type: inline-size"
    >
      {#if app.error}
        <div
          class="absolute top-0 left-0 right-0 z-50 flex items-center justify-between bg-danger px-4 py-2 text-sm text-white"
        >
          <span>{app.error}</span>
          <button onclick={() => app.clearError()} class="ml-2 font-bold">✕</button>
        </div>
      {/if}

      {#if app.screen === "setup"}
        <SetupScreen />
      {:else}
        <TasksScreen />
      {/if}
    </div>
  </div>
</div>
