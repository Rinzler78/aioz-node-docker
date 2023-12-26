#!/bin/bash

git.releases.latest.version.sh "AIOZNetwork/aioz-dcdn-cli-node" | sed 's/[^0-9.]//g'