#!/bin/bash

# Script to remove a Docker Image based on its ID. It will first remove all associated containers
# then remove the image.
IMAGE_IDS=$(docker images | grep \<none\> | tr -s ' ' | cut -d' ' -f3)

if [[ -z $IMAGE_IDS ]]; then
    echo "No zombie images found"
    exit 0
fi

for i in $IMAGE_IDS; do
    CONTAINER_IDS=$(docker ps -a | grep $i | tr -s ' ' | cut -d' ' -f1)

    if [[ ! -z $CONTAINER_IDS ]]; then
        echo "Deleting containers associated with image..."
        docker rm -v $CONTAINER_IDS
    fi

    docker rmi $i
done
