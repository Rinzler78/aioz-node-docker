#!/bin/bash
./helper.docker.stop.sh

name=$(cat helper.docker.name.txt)
echo "Launching : docker run $@ --name $name -it $name"

docker run -P $@ --restart=always --name $name -it $name
