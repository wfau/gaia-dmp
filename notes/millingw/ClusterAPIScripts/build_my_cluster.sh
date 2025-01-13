#!/bin/bash

# we make the following assumptions:
# KUBECONFIG needs to be set to point at the ClusterAPI management cluster
# CLUSTER_SPECIFICATION_FILE is a ClusterAPI yaml file containing templates for the cluster we want to build
# CLUSTER_NAME is consistent with cluster name references in the specification file
# CINDER_SECRETS_FILE contains cinder config details
# CLUSTER_CREDENTIAL_FILE is configured to use an existing OpenStack network, so that we don't need to look up a network id
# TODO handle dynamic network creation; if we're using ceph, better to use a preconfigured network cos otherwise its all a bit of a nightmare

# TODO read this all from a yaml config file, instead of specifying it all here!
export KUBECONFIG=/home/rocky/openstack/k8sdir/config
export CLUSTER_NAME=iris-gaia-red-ceph
#export CLUSTER_SPECIFICATION_FILE=capi-iris-gaia-red-ceph.yaml
#export CLUSTER_SPECIFICATION_FILE=capi-iris-gaia-red-ceph-secret.yaml
export CLUSTER_SPECIFICATION_FILE=capi-iris-gaia-red-ceph-file-test.yaml
export CLUSTER_CREDENTIAL_FILE=appcred-iris-gaia-red-fixed-bootstrap.conf
export CINDER_SECRETS_FILE=cinder-values.yaml

USE_MANILA=true
MANILA_PROTOCOLS_FILE=./manila-csi-kubespray/values.yaml
MANILA_SECRETS_FILE=./manila-csi-kubespray/secrets.yaml
MANILA_STORAGE_CLASS_FILE=./manila-csi-kubespray/sc.yaml
DEFAULT_STORAGE_CLASS=manila

# check all our expected environment variables are set
if [ -z "${KUBECONFIG}" ]; then
   echo environment variable KUBECONFIG not set
   exit 1
fi

if [ -z "${CLUSTER_NAME}" ]; then
   echo environment variable CLUSTER_NAME not set
   exit 1
fi

if [ -z "${CLUSTER_SPECIFICATION_FILE}" ]; then
   echo environment variable CLUSTER_SPECIFICATION_FILE not set
   exit 1
fi

if [ -z "${CLUSTER_CREDENTIAL_FILE}" ]; then
   echo environment variable CLUSTER_CREDENTIAL_FILE not set
   exit 1
fi

if [ -z "${CINDER_SECRETS_FILE}" ]; then
   echo environment variable CINDER_SECRETS_FILE not set
   exit 1
fi

# check all the input config files exist
 
if [ ! -f "${KUBECONFIG}" ]; then
   echo file ${KUBECONFIG} not found
   exit 1
fi

if [ ! -f "${CLUSTER_SPECIFICATION_FILE}" ]; then
   echo file ${CLUSTER_SPECIFICATION_FILE} not found
   exit 1
fi

if [ ! -f "${CLUSTER_CREDENTIAL_FILE}" ]; then
   echo file ${CLUSTER_CREDENTIAL_FILE} not found
   exit 1
fi

if [ ! -f "${CINDER_SECRETS_FILE}" ]; then
   echo file ${CINDER_SECRETS_FILE} not found
   exit 1
fi


# check manila-specific environment variables and files
if [ $USE_MANILA = true ]; then

	if [ -z "${MANILA_PROTOCOLS_FILE}" ]; then
   		echo environment variable MANILA_PROTOCOLS_FILE not set
   		exit 1
	fi

	if [ -z "${MANILA_SECRETS_FILE}" ]; then
   		echo environment variable MANILA_SECRETS_FILE not set
   		exit 1
	fi

	if [ -z "${MANILA_PROTOCOLS_FILE}" ]; then
   		echo environment variable MANILA_STORAGE_CLASS_FILE not set
   		exit 1
	fi

	if [ ! -f "${MANILA_PROTOCOLS_FILE}" ]; then
                echo file ${MANILA_PROTOCOLS_FILE} not found
                exit 1
        fi

        if [ ! -f "${MANILA_SECRETS_FILE}" ]; then
                echo file ${MANILA_SECRETS_FILE} not found
                exit 1
        fi

        if [ ! -f "${MANILA_PROTOCOLS_FILE}" ]; then
                echo file ${MANILA_STORAGE_CLASS_FILE} not set
                exit 1
        fi
fi



# create the cluster via the management cluster
echo building the cluster ...
kubectl apply -f ${CLUSTER_SPECIFICATION_FILE}

# wait a couple of minutes, then loop loooking for the first control plane machine
echo Waiting for cluster to initialise ...
sleep 120

echo Looping till first control plane machine is available
control_plane_status='False'
until [ $control_plane_status == 'True' ];
do
  sleep 60
  control_plane_status=$(clusterctl describe cluster ${CLUSTER_NAME} --grouping=false | grep -E "Machine/${CLUSTER_NAME}-control-plane" | awk -v OFS='\t' 'FNR == 1{print $3}') 
  echo $control_plane_status
done

# we should be able to get the cluster's KUBECONFIG file now
clusterctl get kubeconfig ${CLUSTER_NAME} > ${CLUSTER_NAME}.kubeconfig


# 
# check we can get the initial set of nodes, otherwise we need to wait a bit longer
# we should get at least our first control plane machine listed, with role 'control-plane'
echo looping till control plane nodes responding
control_plane_ready=false
until [ $control_plane_ready = true ];
do
  sleep 60
  get_nodes=$(kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get nodes | awk -v OFS='\t' 'FNR == 2{print $3}')
  echo $get_nodes

  # if it's ready, get_nodes should contain 'control-plane', otherwise keep looping
  if [ $get_nodes == 'control-plane' ]; then
    control_plane_ready=true
  fi 
  echo $control_plane_ready 
done




# start installing the control layer components
echo installing calico components

curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml -O
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f calico.yaml

# create ceph secret before we build our worker nodes;
# config will use this to kernel mount our ceph shares
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f cephx-secret.yaml


kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create secret -n kube-system generic cloud-config --from-file=cloud.conf=${CLUSTER_CREDENTIAL_FILE}
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-roles.yaml
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-role-bindings.yaml
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml                     
# now we loop and wait till the cluster reports success
echo waiting for cluster completion
cluster_status='False'
until [ $cluster_status == 'True' ];
do
  sleep 60
  cluster_status=$( clusterctl describe cluster ${CLUSTER_NAME} --grouping=false | awk -v OFS='\t' 'FNR == 2{print $2}' )
  echo $cluster_status
done
echo Cluster creation complete

# we assume all OpenStack systems will have a Cinder service
# (is this a safe assumption?)
echo Installing cinder driver
helm install --namespace=kube-system -f ${CINDER_SECRETS_FILE} --kubeconfig=./${CLUSTER_NAME}.kubeconfig cinder-csi cpo/openstack-cinder-csi

echo Completed Cluster creation and installed Cinder storage classes


# Ceph / Manila installation
if [ $USE_MANILA = true ]; then
echo Installing Manilla storage class

# install the ceph csi driver
# followed notes at https://gitlab.developers.cam.ac.uk/pfb29/manila-csi-kubespray

helm repo add ceph-csi https://ceph.github.io/csi-charts
helm --kubeconfig=./${CLUSTER_NAME}.kubeconfig install --namespace kube-system ceph-csi-cephfs ceph-csi/ceph-csi-cephfs

# install the manila csi driver
helm  repo add cpo https://kubernetes.github.io/cloud-provider-openstack
helm install --kubeconfig=./${CLUSTER_NAME}.kubeconfig --namespace kube-system manila-csi cpo/openstack-manila-csi -f ${MANILA_PROTOCOLS_FILE}

# configure our access credentials for the manila service
kubectl apply --kubeconfig=./${CLUSTER_NAME}.kubeconfig -f ${MANILA_SECRETS_FILE}

# create a storage class to let us use Manila from kubernetes
kubectl apply --kubeconfig=./${CLUSTER_NAME}.kubeconfig -f ${MANILA_STORAGE_CLASS_FILE}

# make Manila the default storage class, if specified
if [ $DEFAULT_STORAGE_CLASS == 'manila' ]; then
echo Making manila the default storage class
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig patch storageclass csi-manila-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

echo Manila installation complete

fi

# TODO - wait for our workers to become available?

echo Looping till workers are available
worker_nodes_status='False'
until [ $worker_nodes_status == 'True' ];
do
  sleep 60
  worker_nodes_status=$(clusterctl describe cluster ${CLUSTER_NAME} --grouping=false | grep -E "MachineDeployment" | awk -v OFS='\t' '{print $2}')
  echo $worker_nodes_status
done



