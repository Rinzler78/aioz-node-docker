#!/bin/bash
name=$1

if [ -z "$name" ];
then
    name="aioznode"
fi

# Build specified tag and run for 3s
docker build . --tag $name && docker run --env RUN_TIMEOUT=3 --rm $name

# Catch error code. 124 is success code
returnedCode=$?

if [ $returnedCode -eq 143 ]; then
    echo "Success"
    exit 0
fi

echo Returned code : $returnedCode
exit $returnedCode