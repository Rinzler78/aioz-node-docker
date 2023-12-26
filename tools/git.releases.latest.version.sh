#!/bin/bash

REPO=$1
cut -d " " -f2 <<< "$(wget -q -O- https://api.github.com/repos/${REPO}/releases/latest | jq -r '.name')"