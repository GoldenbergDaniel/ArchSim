@echo off
setlocal

set NAME=sim

set ODIN_ROOT=odin
odin build src -out:%NAME%.exe -o:none -use-separate-modules
