@echo off
setlocal

set SRC=src
set OUT=archsim.exe

set KIND=dev
if "%1%"=="d" set KIND=dbg
if "%1%"=="r" set KIND=rls

if "%KIND%"=="dev" set FLAGS=-o:none -use-separate-modules
if "%KIND%"=="dbg" set FLAGS=-o:none -debug
if "%KIND%"=="rls" set FLAGS=-o:speed -no-bounds-check -no-type-assert -disable-assert

set MODE=build
if "%KIND%"=="dev" set MODE=run

if not exist out mkdir out
set ODIN_ROOT=..\odin
..\odin\odin.exe %MODE% %SRC% -out:out/%OUT% %FLAGS%
