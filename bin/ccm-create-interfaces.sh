#!/bin/bash

if [[ -z ${1:+x} ]]; then
    echo "Please specify the number of nodes in your cluster"
    echo "usage ${0} number_nodes"
    exit 1
fi

for i in $(seq 2 ${1}); do
    echo "ifconfig lo0 alias 127.0.0.${i} up" 
    sudo ifconfig lo0 alias 127.0.0.${i} up

    echo "ifconfig lo0 alias 127.0.1.${i} up"
    sudo ifconfig lo0 alias 127.0.1.${i} up
done
