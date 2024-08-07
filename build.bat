@echo off
setlocal

set SRC=src
set OUT=archsim.exe

set MODE=dev
if "%1%"=="d" set MODE=dbg
if "%1%"=="r" set MODE=rls

if "%MODE%"=="dev" set FLAGS=-o:none -use-separate-modules
if "%MODE%"=="dbg" set FLAGS=-o:none -debug
if "%MODE%"=="rls" set FLAGS=-o:speed -no-bounds-check -no-type-assert -disable-assert

set ODIN_ROOT=odin
odin\odin.exe build %SRC% -out:%OUT% %FLAGS%
