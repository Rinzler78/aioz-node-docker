#!/bin/bash
name=$(cat helper.docker.name.txt)
echo "Stopping : docker stop $name"
docker stop "$name"
