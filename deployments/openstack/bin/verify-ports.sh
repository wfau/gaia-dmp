#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <CLOUD_NAME>"
  exit 1
fi

CLOUD_NAME="$1"

# Set the allowed ports
allowed_ports="22,80,443,8080,9100"


# Find the server name that ends in "zeppelin"
server_name=$(openstack server list --os-cloud $CLOUD_NAME --format json | jq -r '.[] | select(.Name | endswith("zeppelin")) | .Name')

# Get the security group Name for the server
security_group_name=$(openstack server show --os-cloud $CLOUD_NAME -c security_groups -f json $server_name | jq -r '.security_groups[0].name')


# Get the list of ingress rules for the security group
rules=$(openstack security group rule list --os-cloud $CLOUD_NAME --format json $security_group_name | jq -c '.[] | {port_range: .["Port Range"], ip_protocol: .["IP Protocol"], remote_group: .["Remote Security Group"], remote_ip: .["Remote IP Prefix"], direction: .["Direction"]}')

res="Security group for server $server_name is correctly configured"
# Verify that only allowed ports are open
while read -r rule; do
  port_range=$(echo "$rule" | jq -r '.port_range')
  ip_protocol=$(echo "$rule" | jq -r '.ip_protocol')
  remote_group=$(echo "$rule" | jq -r '.remote_group')
  direction=$(echo "$rule" | jq -r '.direction')
  allowed=false
  for allowed_port in $(echo "$allowed_ports" | tr ',' ' '); do
    if [[ "$ip_protocol" == "tcp" && "$port_range" == "$allowed_port" || "$port_range" == "$allowed_port:$allowed_port" ]]; then
      allowed=true
    fi
  done
  if [[ "$ip_protocol" == "tcp" && "$allowed" == false && "$remote_group" == "null" && "$direction" != "egress" ]]; then
    res="ERROR: Security group rule $rule allows ports other than $allowed_ports"
    exit 2
  fi
done <<< "$rules"

echo $res

exit 0

