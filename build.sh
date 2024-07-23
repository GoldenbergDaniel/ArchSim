NAME="sim"
MODE=$1

odin build src -out:$NAME -o:none -use-separate-modules
