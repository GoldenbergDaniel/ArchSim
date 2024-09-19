@echo off
setlocal

set SRC=src
set OUT=out/archsim.exe

set MODE=dev
if "%1%"=="d" set MODE=debug
if "%1%"=="r" set MODE=release

if "%MODE%"=="dev"     set FLAGS=-o:none -use-separate-modules
if "%MODE%"=="debug"   set FLAGS=-o:none -debug
if "%MODE%"=="release" set FLAGS=-o:speed -no-bounds-check -no-type-assert -disable-assert

set ACTION=build
@REM if "%ACTION%"=="dev" set ACTION=run

echo [package:%SRC%]
echo [mode:%MODE%]

if not exist out mkdir out
odin %ACTION% %SRC% -out:%OUT% %FLAGS% || exit /b 1
