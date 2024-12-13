#! /bin/bash

#source /tmp/env.rc appcred-rundeckdemo01-clouds.yaml openstack

b64encode(){
  # Check if wrap is supported. Otherwise, break is supported.
  if echo | base64 --wrap=0 &> /dev/null; then
    base64 --wrap=0 $1
  else
    base64 --break=0 $1
  fi
}

export OPENSTACK_CLOUD=iris-gaia-red
export OPENSTACK_CLOUD_YAML_B64=$( cat arcus-red.yaml | b64encode )
export OPENSTACK_CLOUD_CACERT_B64=$( cat arcus-openstack-hpc-cam-ac-uk-chain.pem | b64encode )
export OPENSTACK_FAILURE_DOMAIN=nova
# export OPENSTACK_EXTERNAL_NETWORK_ID=dcb035587-60e2-48eb-ac97-ff5fa38084eba
export OPENSTACK_EXTERNAL_NETWORK_ID=57add367-d205-4030-a929-d75617a7c63e
export OPENSTACK_DNS_NAMESERVERS=8.8.8.8
export OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR=gaia.vm.cclake.4vcpu
export OPENSTACK_NODE_MACHINE_FLAVOR=gaia.vm.cclake.54vcpu
export OPENSTACK_IMAGE_NAME=Ubuntu-Jammy-22.04-20240514-kube-1.30.2
export OPENSTACK_SSH_KEY_NAME=iris-malcolm-kube-test-keypair

export KUBERNETES_VERSION=1.30.2

# optional
export CLUSTER_NAME=iris-gaia-red-demo
export CONTROL_PLANE_MACHINE_COUNT=3
export WORKER_MACHINE_COUNT=2

