# ArchSim
Simulate a fantasy assembly language from the CLI. W.I.P.

The assembly program can be found in `data/main.asm`.

# Instructions
. In order to build from source, the only external dependency is a C compiler toolchain, such as LLVM (Clang) or MSVC (Visual Studio). An Odin compiler is bundled in the repo.
```bash
./build.sh || build.bat
./sim || sim.exe
```

**NOTE**: On macOS, you may need to run the following command to give the Odin compiler permission to execute.
```bash
chmod +x odin/odin
```

**NOTE**: Currently, the only platforms suported out-of-the-box are x64_86 Windows and x64_86 macOS. Other platforms may be supported but require the Odin compiler to be installed seperately. https://odin-lang.org/
