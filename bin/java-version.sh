#!/bin/bash

JAVA_HOME_PATH_FILE="/Users/anthony/.java_home"
JAVA_VM_DIR="/Library/Java/JavaVirtualMachines"
USR_LOCAL_BIN_DIR="/usr/local/bin"
JAVA_BIN_LIST=(
java
javac
javadoc
javap
)

function available_versions()
{
  echo "Available Java versions are:"
  echo "${available_version_numbers}"
}


current_full_version=$(java -version 2>&1 | grep version | sed 's/java\ version\ //')
current_version_number=$(echo ${current_full_version} | cut -d' ' -f1 | tr -d '"')
available_full_versions=$(ls ${JAVA_VM_DIR})
available_version_numbers=$(echo "${available_full_versions}" | cut -d'-' -f2 | cut -d'_' -f1 | sed 's/\.jdk//')

new_version_number="${1}"
if [[ -z "${new_version_number}" ]]
then
  if [[ -z "${current_full_version}" ]]
  then
    echo "No Java version is set!"
    echo
  else
    echo "Current Java version is ${current_full_version}"
    echo
  fi
  available_versions
  exit 0
fi

if [[ "${new_version_number}" = "${current_version_number}" ]]
then
  echo "Java version ${current_full_version} already set!"
  exit 0
fi

new_full_version_number=$(echo "${available_full_versions}" | grep "${new_version_number}")
if [[ -z "${new_full_version_number}" ]]
then
  echo "Java version ${new_version_number} does not exist. Leaving Java version as ${current_full_version}"
  echo
  available_versions
  exit 1
fi

for java_bin in ${JAVA_BIN_LIST[@]}
do
  ln -sfn ${JAVA_VM_DIR}/${new_full_version_number}/Contents/Home/bin/${java_bin} ${USR_LOCAL_BIN_DIR}/${java_bin}
done

echo "export JAVA_HOME=${JAVA_VM_DIR}/${new_full_version_number}/Contents/Home" > ${JAVA_HOME_PATH_FILE}
echo "Run the following command to set the JAVA_HOME variable in the shell"
echo "\$ source ~/.java_home"
