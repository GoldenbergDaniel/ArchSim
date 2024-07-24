#!/bin/bash

export ODIN_ROOT="odin"

NAME="sim"

odin build src -out:$NAME -o:speed -use-separate-modules
