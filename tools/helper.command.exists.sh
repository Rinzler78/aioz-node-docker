#!/bin/bash
# if ! command -v $1 &> /dev/null
if ! which $1 &> /dev/null
then
    exit 1
fi
