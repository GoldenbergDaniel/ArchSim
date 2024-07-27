#!/bin/bash

export ODIN_ROOT="odin"

NAME="archsim"

odin build src -out:$NAME -o:none -use-separate-modules
