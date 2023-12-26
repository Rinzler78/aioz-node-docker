#!/bin/bash
## Update packages
dist.update.sh
## Upgrade packages
dist.upgrade.sh

## Install aioznode
if ! node.install.sh
then
    exit 1
fi

## Install aioznode
if ! wallet.configure.sh
then
    exit 1
fi

## Clean packages
dist.clean.sh
