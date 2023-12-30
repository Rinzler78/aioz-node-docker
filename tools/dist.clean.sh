#!/bin/sh
apk del $(apk list -I | awk -F'-' '/linux/ {print $1}' | grep -v $(uname -r))
apk cache clean
