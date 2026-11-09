#!/bin/bash
name=$(cat helper.docker.name.txt)
echo "docker build -t $name ."
docker build -t "$name" .
