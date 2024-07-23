@echo off
setlocal

set NAME=sim

odin build src -out:%NAME%.exe -o:none -use-separate-modules
