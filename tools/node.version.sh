#!/bin/bash

if node.isInstalled.sh
then
    #node.version # Return empty string
    $BINARY_NAME version 2>&1 | sed 's/[^0-9.]//g'
    exit 0
fi

exit 1
