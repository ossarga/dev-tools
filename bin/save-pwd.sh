#!/bin/bash

PWD_FILE="~/.pwd-path"

echo "Saving current working directory path to file ${PWD_FILE}."
echo "Run the following command to set the path in a new shell"
echo "\$ source ${PWD_FILE}"

current_pwd=$(pwd)
echo "cd ${current_pwd}" > "${PWD_FILE}"
