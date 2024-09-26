<div>
  <input type="text" placeholder="enter text here" bind:value={inputStr}><br><br>
  <button on:click={runOdin}>
    Run
  </button>
</div>

<style>
  input {
    padding: 2%;
    text-align: center;
    font-size: 30px;
  }
</style>

<script>
  import { wasm, odin, WasmMemoryInterface } from "../wasm.js"
  
  let inputStr = ""

  function runOdin()
  {
    if (wasm && inputStr != "") {
      const strPtr = odin.exports.mem_alloc(inputStr.length)
      const strLen = wasm.storeString(strPtr, inputStr)
      const resAddr = odin.exports.do_string(strPtr, strLen)
      inputStr = wasm.loadString(resAddr, strLen)
      
      odin.exports.mem_clear()
    }
  }
</script>
