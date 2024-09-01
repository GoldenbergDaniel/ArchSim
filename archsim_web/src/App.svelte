<main>
  <div>
    <a href="https://vitejs.dev" target="_blank" rel="noreferrer">
      <img src={viteLogo} class="logo vite" alt="Vite Logo"/>
    </a>
    <a href="https://svelte.dev" target="_blank" rel="noreferrer">
      <img src={svelteLogo} class="logo svelte" alt="Svelte Logo"/>
    </a>
    <a href="https://odin-lang.org" target="_blank" rel="noreferrer">
      <img src={odinLogo} class="logo odin" alt="Odin Logo"/>
    </a>
  </div>
  <h1>Vite + Svelte + Odin</h1>
  <div class="card">
    <FromOdin/>
  </div>
</main>

<style>
  .logo {
    height: 6em;
    padding: 1.5em;
    will-change: filter;
    transition: filter 300ms;
  }

  .logo.vite:hover {
    filter: drop-shadow(0 0 2em #646cffaa);
  }

  .logo.svelte:hover {
    filter: drop-shadow(0 0 2em #ff3e00aa);
  }

  .logo.odin:hover {
    filter: drop-shadow(0 0 2em #2B5081);
  }
</style>

<script>
  import viteLogo from "/vite.svg"
  import svelteLogo from "./assets/svelte.svg"
  import odinLogo from "./assets/odin.svg"

  import FromOdin from "./components/FromOdin.svelte"

  import initWasm from "./wasm.js"

  initWasm()
</script>

