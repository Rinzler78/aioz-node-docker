#!/bin/bash

REPO=$1
curl -sL https://api.github.com/repos/$REPO/releases/latest | jq '.body' -r | grep -o 'https://[^)]*' 
