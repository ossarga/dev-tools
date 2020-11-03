#!/bin/bash

set -e

CREDENTIALS_LIB_FILE="~/.aws/.credentials-library"

CREDENTIALS_FILE="~/.aws/credentials"
CURRENT_CONFIG_FILE="~/.aws/.current"

CREDENTIALS_TMP_FILE="~/.aws/.credentials.tmp"
CURRENT_CONFIG_TMP_FILE="~/.aws/.current.tmp"

function available_configs()
{
  echo "Available configs are:"
  if [[ -f ${CREDENTIALS_LIB_FILE} ]]
  then
    grep -e "\[.*\]" ${CREDENTIALS_LIB_FILE} | sed 's/\[\(.*\)\]/\1/'
  else
    echo "" > ${CREDENTIALS_LIB_FILE}
  fi
}

new_config="${1}"
current_config=""
if [[ -f ${CURRENT_CONFIG_FILE} ]]
then
  current_config="$(cat ${CURRENT_CONFIG_FILE})"
fi

if [[ -z "${new_config}" ]]
then
  if [[ -z "${current_config}" ]]
  then
    echo "No AWS config is set!"
    echo
  else
    echo "Current AWS config is '${current_config}'"
    echo
  fi
  available_configs
  exit 0
fi

if [[ "${new_config}" = "${current_config}" ]]
then
  echo "AWS config '${current_config}' already set!"
  exit 0
fi

if [[ -z $(grep -w -A2 "\[${new_config}\]" ${CREDENTIALS_LIB_FILE}) ]]
then
  echo "AWS config '${new_config}' does not exist. Leaving AWS config as '${current_config}'"
  echo
  available_configs
  exit 1
fi


echo "[default]" > ${CREDENTIALS_TMP_FILE}
echo $(grep -w -A2 "\[${new_config}\]" ${CREDENTIALS_LIB_FILE} | grep aws_access_key_id) >> ${CREDENTIALS_TMP_FILE}
echo $(grep -w -A2 "\[${new_config}\]" ${CREDENTIALS_LIB_FILE} | grep aws_secret_access_key) >> ${CREDENTIALS_TMP_FILE}
echo "" >> ${CREDENTIALS_TMP_FILE}
cat ${CREDENTIALS_LIB_FILE} >> ${CREDENTIALS_TMP_FILE}

echo "${new_config}" > ${CURRENT_CONFIG_TMP_FILE}

if [[ -f ${CREDENTIALS_FILE} ]]
then
  mv ${CREDENTIALS_FILE} ${CREDENTIALS_FILE}.old
fi
if [[ -f ${CURRENT_CONFIG_FILE} ]]
then
  mv ${CURRENT_CONFIG_FILE} ${CURRENT_CONFIG_FILE}.old
fi

echo "Setting AWS config to '${new_config}'"
mv ${CREDENTIALS_TMP_FILE} ${CREDENTIALS_FILE}
mv ${CURRENT_CONFIG_TMP_FILE} ${CURRENT_CONFIG_FILE}
