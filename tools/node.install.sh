#!/bin/bash
seconds=5

if ! node.isUpToDate.sh
then
    echo "Installation will start in $seconds s ..."
    sleep $seconds
    remoteVersion="$(node.remoteVersion.sh)"
    latestReleaseUrl=$(git.releases.latest.url.sh $REPO_NAME)
    
    tmpFilename=tmp.aioznode.tar.gz

    echo "Downloading $remoteVersion at $latestReleaseUrl ..."
    wget --output-document=$tmpFilename $latestReleaseUrl 2>/dev/null

    if [ -f $tmpFilename ]; then
        tar -xvzf $tmpFilename
        filename=aioznode-linux-amd64*

        echo "Moving $filename to /bin/$BINARY_NAME ..."
        mv $filename /bin/$BINARY_NAME
        rm $tmpFilename
    else
        echo "download failed"
    fi
    
    currentVersion="$(node.version.sh)"
    echo "aioznode $currentVersion installed"
fi

exit 0
