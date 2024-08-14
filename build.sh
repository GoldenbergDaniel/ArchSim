#!/bin/bash

SRC="src"
OUT="archsim"

MODE="dev"
if [[ $1 == "d" ]]; then MODE="dbg"; fi
if [[ $1 == "r" ]]; then MODE="rls"; fi

if [[ $MODE == "dev" ]]; then FLAGS="-o:none -use-separate-modules"; fi
if [[ $MODE == "dbg" ]]; then FLAGS="-o:none -debug"; fi
if [[ $MODE == "rls" ]]; then FLAGS="-o:speed -no-bounds-check -no-type-assert -disable-assert"; fi

if [[ ! -d "out" ]]; then mkdir out; fi
pushd out
  export ODIN_ROOT="odin"
  odin build $SRC -out:$OUT $FLAGS
popd
