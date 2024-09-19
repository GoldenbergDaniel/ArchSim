#!/bin/bash
set -e

SRC="src"
OUT="out/archsim"

MODE="dev"
if [[ $1 == "d" ]]; then MODE="debug"; fi
if [[ $1 == "r" ]]; then MODE="release"; fi

if [[ $MODE == "dev" ]];     then FLAGS="-o:none -use-separate-modules"; fi
if [[ $MODE == "debug" ]];   then FLAGS="-o:none -debug"; fi
if [[ $MODE == "release" ]]; then FLAGS="-o:speed -no-bounds-check -no-type-assert"; fi

echo [package:$SRC]
echo [mode:$MODE]

if [[ ! -d "out" ]]; then mkdir out; fi
odin build $SRC -out:$OUT $FLAGS
