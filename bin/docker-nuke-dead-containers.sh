#!/bin/bash

for ps_id in $(docker ps -a | grep Exited | tr -s ' ' | cut -d' ' -f1)
do
  echo "Removing: $(docker ps -a | grep ${ps_id} | tr -s ' ')"
  docker rm ${ps_id}
done
