#!/bin/bash

for i in $(kubectl get deployments --all-namespaces | tr -s ' ' '#' | cut -d'#' -f1,2 | grep -v NAMESPACE)
do
  kubectl delete -n $(echo ${i} | cut -d'#' -f1) deployment $(echo ${i} | cut -d'#' -f2)
done
