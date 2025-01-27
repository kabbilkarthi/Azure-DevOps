#!/bin/bash

# Remove all stopped docker images and containers

docker image prune -a -f
docker container prune -f
