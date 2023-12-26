#!/bin/bash

LOCAL_VERSION=$(node.version.sh)
REMOTE_VERSION=$(node.remoteVersion.sh)

echo "Local version : $LOCAL_VERSION"
echo "Remote version : $REMOTE_VERSION"

if ! node.isInstalled.sh
then
    echo "Need to install"
    exit 1
fi

if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]
then
    echo "Need to update to $REMOTE_VERSION"
    exit 1
fi

echo "Up to date"

exit 0