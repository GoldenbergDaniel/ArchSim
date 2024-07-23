NAME="sim"
MODE=$1

export ODIN_ROOT="odin"
odin build src -out:$NAME -o:none -use-separate-modules
