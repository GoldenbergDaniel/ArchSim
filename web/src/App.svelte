<main>
  <div id="nav">
    <a href="https://riscv.org/" target="_blank" rel="noreferrer">
      <img src={riscvLogo} class="logo riscv" alt="Vite Logo"/>
    </a>
    <h1>archsim</h1>
    <!-- <a href="https://webassembly.org/" target="_blank" rel="noreferrer">
      <img src={wasmLogo} class="logo wasm" alt="Svelte Logo"/>
    </a>
    <a href="https://odin-lang.org" target="_blank" rel="noreferrer">
      <img src={odinLogo} class="logo odin" alt="Odin Logo"/>
    </a> -->
   
  </div>
  <div id="holder">
    <div id="left-side">
      <textarea id="editor" rows="10" cols="50"
                autocorrect="off" autocapitalize="off" spellcheck="false"></textarea>
    </div>
    <div id="right-side">
      <h1>VIEWS</h1>
      <FromOdin/>
    </div>
  </div>
</main>

<style>
  #nav {
    margin: 0;
    padding: 5px;
    top: 0;
    text-align: left;
    /* border-bottom: 1px solid white; */
    border-top: 1px solid #101010;
    background-color: #101010;
    display: flex;
    align-items: center;
  }
  #nav h1 {
    margin: 0 0 0 10px;
  }

  #holder {
    height: 100%;
  }

  #editor {
    resize: none;
    position: relative;
    width: 90%;
    height: 100%;
    font-size: 20px;
    font-family: monospace;
    line-height: 1.5em;
    background-color: #101010;
    /* margin: 1em; */
    padding: 10px;
    box-sizing: border-box;
    overflow-y: scroll;
    border: none;
  }

  #editor:focus {
    outline: none;
  }

  #left-side, #right-side {
    width: 50%;
    float: left;
  }

  #left-side {
    border: 1px solid red;
    border-right: 3px solid #101010;
    height: 90%;
  }

  #right-side {
    width: calc(50% - 4px);
  }

  .logo {
    height: 2em;
    padding: 0em;
    will-change: filter;
    transition: filter 300ms;
  }

  .logo.riscv:hover {
    filter: drop-shadow(0 0 2em #2b336e);
  }

  /* .logo.wasm:hover {
    filter: drop-shadow(0 0 2em #6056e7);
  }

  .logo.odin:hover {
    filter: drop-shadow(0 0 2em #2B5081);
  } */
</style>

<script>
  import riscvLogo from "/riscv.svg"
  import wasmLogo from "./assets/wasm.svg"
  import odinLogo from "./assets/odin.svg"

  import FromOdin from "./components/FromOdin.svelte"

  import initWasm from "./wasm.js"

  initWasm()
</script>
