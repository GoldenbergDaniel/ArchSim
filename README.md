# ArchSim
Simulate a fantasy assembly language from the command line. W.I.P.

The assembly program can be found in `data/main.asm`.

# Instructions
In order to build from source, the only external dependency is MSVC (Visual Studio) on Windows and Clang on macOS. An Odin compiler is bundled in the repo.
1. Unzip `odin/LLVM-C.dll.zip` on Windows or `odin/libs/libLLVM.dylib.zip` on macOS.
2. Run the following commands
```bash
./build.sh || build.bat
./sim || sim.exe
```

**NOTE**: On macOS, you may need to run the following command before running `./build.sh` to give the Odin compiler permission to execute.
```bash
chmod +x odin/odin
```

**NOTE**: Currently, the only platforms supported out-of-the-box are x64_86 Windows and x64_86 macOS. Other platforms may be supported but require the Oin compiler to be installed seperately. https://odin-lang.org/
