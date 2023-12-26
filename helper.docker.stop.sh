#!/bin/bash
name=$(cat helper.docker.name.txt)
echo "Stoping : docker stop $name"
docker stop $name
