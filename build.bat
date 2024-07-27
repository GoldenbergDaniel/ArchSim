@echo off
setlocal

set ODIN_ROOT=odin

set NAME=archsim

odin\odin.exe build src -out:%NAME%.exe -o:none -use-separate-modules
