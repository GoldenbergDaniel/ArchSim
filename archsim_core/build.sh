#!/bin/bash
set -e

SRC="src"
OUT="out/archsim"

MODE="dev"
if [[ $1 == "d" ]]; then MODE="dbg"; fi
if [[ $1 == "r" ]]; then MODE="rls"; fi

if [[ $MODE == "dev" ]]; then FLAGS="-o:none -use-separate-modules"; fi
if [[ $MODE == "dbg" ]]; then FLAGS="-o:none -debug"; fi
if [[ $MODE == "rls" ]]; then FLAGS="-o:speed -no-bounds-check -no-type-assert"; fi

echo [package:$SRC]
echo [mode:$MODE]

if [[ ! -d "out" ]]; then mkdir out; fi
odin build $SRC -out:$OUT $FLAGS
