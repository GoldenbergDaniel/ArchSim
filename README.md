# ArchSim
Simulate a fantasy assembly language from the CLI.

# Instructions
Natively compiles on Windows and macOS. Odin compiler is packaged in the repo. For building, The only external dependecy is a C compiler toolchain, such as LLVM (Clang) on macOS and MSVC (Visual Studio) on Windows.
```bash
./build.sh || build.bat
./sim || sim.exe
```

On macOS, you may need to run the following command to give the Odin compiler permission to execute.
```bash
chmod +x "odin/odin"
```
