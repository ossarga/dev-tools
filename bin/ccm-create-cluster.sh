#!/bin/bash

YELLOW='\033[0;33m'
YELLOW_BOLD='\033[1;33m'
NC_BOLD='\033[1m'
NC='\033[0m' # No Color

function usage()
{
    cat << EOF
This script creates a CCM cluster.

usage: ccm_create_cluster [OPTIONS] cluster_name

Options
 -n     Node topology in cluster. Use a ':' to denote a datacenter e.g. 3:3. Default is 3.

 -r     Number of racks in cluster. Default is 1.

 -v     Cassandra version. Default is 3.11.8.

 -c     Set configuration setting in the cassandra.yaml file.
          Argument must be in the format: 'CONFIGURATION_SETTING:VALUE'

 -h     Help and usage.
EOF
    exit 2
}

function update_node_config {
  node_num=${1}
  rack_num=${2}
  datacenter_num=${3}

  for key_value_setting in ${yaml_config_settings}
  do
    setting_key=$(echo ${key_value_setting} | cut -d':' -f1)
    setting_val=$(echo ${key_value_setting} | cut -d':' -f2)
    sed -ie "s/${setting_key}\:\ .*/${setting_key}:\ ${setting_val}/g" \
      ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra.yaml
  done

  sed -ie "s/dc=.*/dc=datacenter${datacenter_num}/g" \
    ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra-rackdc.properties
  sed -ie "s/rack=.*/rack=rack${rack_num}/g" \
    ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra-rackdc.properties

  sed -ie 's/\#MAX_HEAP_SIZE=\"4G\"/MAX_HEAP_SIZE=\"500M\"/g' \
    ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra-env.sh
  sed -ie 's/\#HEAP_NEWSIZE=\"800M\"/HEAP_NEWSIZE=\"120M\"/g' \
    ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra-env.sh
  sed -ie 's/LOCAL_JMX=yes/LOCAL_JMX=no/g' \
    ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra-env.sh
  sed -ie 's/com\.sun\.management\.jmxremote\.authenticate=true/com.sun.management.jmxremote.authenticate=false/g' \
    ~/.ccm/${cluster_name}/node${node_num}/conf/cassandra-env.sh
}


#
# Start main script execution
#
node_topology=3
number_racks=1
cassandra_version=3.11.8
yaml_config_settings="num_tokens:16 \
  endpoint_snitch:GossipingPropertyFileSnitch"

while getopts n:r:v:c:h opt_flag; do
  case ${opt_flag} in
    n)
        node_topology=${OPTARG}
        ;;
    r)
        number_racks=${OPTARG}
        ;;
    v)
        cassandra_version=${OPTARG}
        ;;
    c)
        yaml_config_settings="${yaml_config_settings} ${OPTARG}"
        ;;
    h)
        usage
        ;;
  esac
done

shift $(($OPTIND - 1))

if [[ "$#" -eq 0 ]]
then
    usage
fi

cluster_name=${1}

if [[ "x${cluster_name}" == "x" ]]
then
    usage
fi

yaml_config_settings="cluster_name:${cluster_name} \
  ${yaml_config_settings}"

echo -e "Creating cluster: '${NC_BOLD}${cluster_name}${NC}'"
echo -e "Cassandra version: ${NC_BOLD}${cassandra_version}${NC}"
echo -e "Node topology: ${NC_BOLD}${node_topology}${NC}"
echo -e "Number racks: ${NC_BOLD}${number_racks}${NC}"
echo

ccm create ${cluster_name} -v ${cassandra_version}

echo -n "Generating seed list ..."
seed_list=""
node_num=1
for number_nodes in $(echo "${node_topology}" | tr ':' ' ')
do
  node_offset=${number_nodes}
  for rack_num in $(seq ${number_racks})
  do
    if [[ -z "${seed_list}" ]]
    then
      seed_list="127.0.0.${node_num}"
    else
      seed_list="${seed_list},127.0.0.${node_num}"
    fi
    node_offset=$((${node_offset} - 1))
    node_num=$((${node_num} + 1))
 
    if [[ "${rack_num}" -ge "${number_nodes}" ]]
    then
      break
    fi
  done
  node_num=$((${node_num} + ${node_offset}))
done
echo -n " done!"
echo
echo "Seeds: ${seed_list}"

yaml_config_settings="${yaml_config_settings} \
  seeds:${seed_list}"


SEED_NODE_FLAG="-s"
datacenter_num=1
node_num=1
for number_nodes in $(echo "${node_topology}" | tr ':' ' ')
do
  rack_num=1
  echo
  echo "Creating datacenter${datacenter_num}"
  
  if ((number_nodes % number_racks))
  then
    echo -e "${YELLOW_BOLD}[WARNING]${YELLOW} The number of nodes in datacenter ${datacenter_num} and racks you have chosen will give uneven distibution of nodes in each rack.${NC}"
  fi

  for node_itr in $(seq ${number_nodes})
  do
    echo "Adding 'node${node_num}' to rack ${rack_num}"
    ccm add node${node_num} -i 127.0.0.${node_num} -j 7${node_num}00 -r 0 -b ${SEED_NODE_FLAG};

    update_node_config ${node_num} ${rack_num} ${datacenter_num}
    # Localhost aliases
    echo "interface for 127.0.0.${node_num} created"
    sudo ifconfig lo0 alias 127.0.0.${node_num} up

    rack_num=$((rack_num + 1))

    if [[ "${rack_num}" -gt "${number_racks}" ]]
    then
      rack_num=1
      SEED_NODE_FLAG=""
    fi
 
    node_num=$((${node_num} + 1))
  done

  datacenter_num=$((${datacenter_num} + 1))
  SEED_NODE_FLAG="-s"
done

sed -ie 's/use_vnodes\:\ false/use_vnodes:\ true/g' ~/.ccm/${cluster_name}/cluster.conf
