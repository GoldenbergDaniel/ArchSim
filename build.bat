@echo off
setlocal

set ODIN_ROOT=odin

set NAME=sim

odin build src -out:%NAME%.exe -o:none -use-separate-modules
