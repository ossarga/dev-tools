#!/bin/bash

SSH_AGENT_CONF="~/.ssh-agent"

function get_running_ssh_agent_pids () {
  # We only want to find the processes that are named "ssh-agent" and ignore things like "/usr/bin/ssh-agent -l"
  echo $(ps aux | grep ssh-agent | tr -s ' ' | cut -d' ' -f2,11 | grep -e "[0-9]*\ ssh\-agent" | cut -d' ' -f1)
}

function get_running_ssh_agent_pids_count () {
  # We only want to find the processes that are named "ssh-agent" and ignore things like "/usr/bin/ssh-agent -l"
  echo $(ps aux | grep ssh-agent | tr -s ' ' | cut -d' ' -f2,11 | grep -e "[0-9]*\ ssh\-agent" | cut -d' ' -f1 | wc -l)
}

function kill_other_ssh_agent_ps () {
  echo "Killing stale ssh-agents"
  local ssh_agent_pid_list=${1}
  local current_pid=${2}

  for pid_itr in ${ssh_agent_pid_list}
  do
    if [ "${pid_itr}" != "${current_pid}" ]
    then
      kill -9 ${pid_itr}
    fi
  done
}

function set_running_ssh_agents () {
  local current_ssh_agent_pid=${1}
  local num_ssh_agents_to_keep_alive=0

  if [ -n "${current_ssh_agent_pid}" ]
  then
    num_ssh_agents_to_keep_alive=1
  fi

  if [ $(get_running_ssh_agent_pids_count) -gt ${num_ssh_agents_to_keep_alive} ]
  then
    kill_other_ssh_agent_ps "$(get_running_ssh_agent_pids)" "${current_ssh_agent_pid}"
  fi

  if [ $(get_running_ssh_agent_pids_count) -eq 0 ]
  then
    echo "Creating new ssh-agent"
    ssh-agent > ${SSH_AGENT_CONF}
  fi
}

function is_ssh_agent_pid_alive () {
  local rtn_value=1
  local ssh_agent_pid=${1}

  if [ $(ps aux | grep "${ssh_agent_pid}" | grep -v "grep" | wc -l) -eq 0 ]
  then
    rtn_value=0
  fi

  return ${rtn_value}
}

function get_pid_from_config () {
  echo $(cat ${SSH_AGENT_CONF} | grep SSH_AGENT_PID | sed 's/SSH_AGENT_PID=\([0-9]*\).*/\1/g')
}

function prune_stale_auth_socks () {
  local current_ssh_auth_sock_path=$(cat ${SSH_AGENT_CONF} | grep SSH_AUTH_SOCK | sed 's/SSH_AUTH_SOCK=//g' | sed 's/;\ export\ SSH_AUTH_SOCK;//g')
  local ssh_auth_sock_parent_dir=$(echo ${current_ssh_auth_sock_path} | cut -d'/' -f1,2,3,4,5,6)
  local current_ssh_auth_sock_dir=$(echo ${current_ssh_auth_sock_path} | cut -d'/' -f8)
  local ssh_auth_sock_list=$(ls ${ssh_auth_sock_parent_dir} | grep "ssh-")
  local clean_up_executed=false

  for ssh_auth_sock_itr in ${ssh_auth_sock_list}
  do
    if [ "${ssh_auth_sock_itr}" != "${current_ssh_auth_sock_dir}" ]
    then
      rm -fr ${ssh_auth_sock_parent_dir}/${ssh_auth_sock_itr}
      clean_up_executed=true
    fi
  done

  if [ "${clean_up_executed}" = "true" ]
  then
    echo "Cleaned up stale auth stocks"
  fi
}

#----- Main ----

# Look for ssh-agent file
# * if missing
#   - kill current ssh-agents
#   - create new ssh-agent
# * if present
#   * if PID in file is dead
#      - kill remaining ssh-agents
#      - create new agent
#
# - kill ssh-agents with a PID different to one in ssh-agent file
# - source ssh-agent file

echo "Checking ssh-agent env file ..."

current_ssh_agent_pid=0

if [ -f ${SSH_AGENT_CONF} ]
then
  current_ssh_agent_pid=$(get_pid_from_config)
  echo "ssh-agent env file found with pid: ${current_ssh_agent_pid}"

  is_ssh_agent_pid_alive "${current_ssh_agent_pid}"
  rtn_code=${?}

  if [ ${rtn_code} -eq 0 ]
  then
    echo "No ssh-agent process running with pid: ${current_ssh_agent_pid}"
    set_running_ssh_agents
    current_ssh_agent_pid=$(get_pid_from_config)
  else
    echo "ssh-agent is running with pid: ${current_ssh_agent_pid}"
    set_running_ssh_agents "${current_ssh_agent_pid}"
  fi
else
  echo "No ssh-agent env file found!"
  set_running_ssh_agents
fi

source ${SSH_AGENT_CONF}

prune_stale_auth_socks
