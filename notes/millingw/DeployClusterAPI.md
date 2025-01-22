# Deploy Kubernetes Cluster on Arcus with ClusterCtl

Based on Amy's notes https://git.ecdf.ed.ac.uk/akrause/openstack-bits-and-pieces/-/blob/main/ClusterAPI/CreateCluster.md

Manila deployment based on Paul Browne's notes https://gitlab.developers.cam.ac.uk/pfb29/manila-csi-kubespray

Used VM "gaia_dataset_one" in somerville gaia_jade project as command and control VM.

Management cluster created in Somerville gaia_jade project using CAPI Magnum command line client, although management cluster could in theory be anywhere with vpn access.

Prerequisites:

Existing kubernetes cluster (management cluster): used existing cluster "malcolm_k8s" on somerville, created using Magnum python client. 
However, process for creating initial cluster should not matter here. 
Access to target OpenStack instance where new cluster will be generated. 
A source recent ubuntu image must already be present in the target OpenStack project. 
These notes assume a useable project-level router has already been provisioned in the target OpenStack project.

Required software:
On command / control machine, need to install python, ansible, kubectl, clusterctl, packer (and dependencies).
Need ansible / packer to build images on target OpenStack instance
Need clusterctl for cluster template generation / deployment
Need kubeconfig for management cluster, access credentials for target openstack cluster. 

On gaia_dataset_one VM (on Somerville):

Install kubectl:

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Install dependencies
```
pip install python-dev
pip install python-openstackclient
pip install python-magnumclient
pip install ansible
sudo dnf install make
sudo dnf install git
sudo dnf install wget
sudo dnf install yq
```
# Create and export boostrap cluster details so that we can access it with kubectl (assuming clouds.yaml etc already points to bootstrap OpenStack instance)
```
openstack coe cluster config --dir /home/rocky/openstack/k8sdir --force --output-certs malcolm_k8s --os-cloud somerville-jade
export KUBECONFIG=/home/rocky/openstack/k8sdir/config
KUBECONFIG now points at our (yet-to-be-initialised) management cluster
```
# Install clusterctl:

```
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.8.1/clusterctl-linux-amd64 -o clusterctl
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
```

Initialise the management cluster for deploying k8s into OpenStack clouds. 
This turns our starting magnum-created kubernetes cluster into a ClusterAPI management cluster.

```
clusterctl init --infrastructure openstack
```

Our cluster on Somerville is now our management cluster. We can use this to deploy and manage multiple OpenStack clusters on different sites.  
If the management cluster is accidently deleted, then our worker clusters become independent and will still work, but won't be manageable via ClusterAPI.

# Build CAPI image in target OpenStack environment:

Next, we need to build a control image in our target OpenStack environment. The management cluster will use this image to create clusters in the target project.  
Prerequisites are an existing Ubuntu image in the target project, and OpenStack credentials with project-level permissions for the target project.

Install Packer on command/control VM:

```
curl https://releases.hashicorp.com/packer/1.11.2/packer_1.11.2_linux_amd64.zip --output packer_1.11.2_linux_amd64.zip
unzip packer_1.11.2_linux_amd64.zip
cd packer
sudo mv packer /usr/local/bin/packer
```

Create reqs-build.pkr.hcl 

```
packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/openstack"
    }
  }
}
packer {
  required_plugins {
    ansible = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

packer init reqs-build.pkr.hcl
```

create packer_var_file.json, edited for arcus red project

Note that I had to add a "packer_build_ingest" security group to the arcus project to allow ssh access for packer to build the image
"networks" is existing router in OpenStack project, did not have to create this
CUDN-Internet is existing floating ip pool name in gaia red project
Had to work out flavor and image name from looking at options in the arcus gaia red OpenStack project and doing some trial VM creations to get good combinations
source_image has to be the name of an existing Ubuntu image in the target OpenStack project
image_name is the name of the CAPI magnum image that will be built in the target OpenStack project (ie a new image will be built with this name)

```
{
  "source_image": "Ubuntu-Jammy-22.04-20240514",
  "network_discovery_cidrs": "10.1.0.0/24",
  "networks": "77c534e1-1de2-400b-a315-9d1c9768c99f",
  "flavor": "gaia.vm.cclake.26vcpu",
  "floating_ip_network": "CUDN-Internet",
  "image_name": "Ubuntu-Jammy-22.04-20240514-kube-1.30.2",
  "image_visibility": "private",
  "image_disk_format": "raw",
  "volume_type": "",
  "ssh_username": "ubuntu",
  "kubernetes_deb_version": "1.30.2-1.1",
  "kubernetes_semver": "v1.30.2",
  "kubernetes_series": "v1.30",
  "security_groups": "packer_build_ingest"
}
```

build the CAPI image in the target OpenStack project:

```
cd image-builder/images/capi
PACKER_VAR_FILES=/path/to/packer_var_file.json make build-openstack-ubuntu-2204
take some time to run, generates new image Ubuntu-Jammy-22.04-20240514-kube-1.30.2 in the target OpenStack project
Check in the OpenStack project that the image built ok (either via the openstack client, or via the Horizon GUI for the target OpenStack project
```

# Create new Kubernetes cluster for actual use

The following assumes the management cluster is up and running.

## Create application credentials

Create application credentials in Openstack for the target project (here, iris-gaia-red on Arcus) where the Kubernetes cluster will be created and store in `arcus-red.yaml`.

```
arcus-red.yaml
clouds:


  iris-gaia-red:
    auth:
      auth_url: https://arcus.openstack.hpc.cam.ac.uk:5000
      application_credential_id: "*********"
      application_credential_secret: "******"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
    auth_type: "v3applicationcredential"
```

## Set up environment

Get the OpenStack API server certificates by browsing to the horizon interface, click on the padlock symbol, view certificates, download certificate chain
If necessary, create a new keypair in the OpenStack project that will used to access OpenStack during the cluster creation
Notes assume server certificates saved to arcus-openstack-hpc-cam-ac-uk.pem

Create environment variable script for configuring clusterctl deployment.
Note that a value must be supplied for OPENSTACK_DNS_NAMESERVERS must be supplied for the config file generation; however, it may be necessary to edit or delete this from the generated config file (see below).
(We've seen that on Arcus the value is ignored, but on BSC it is used directly and messes things up)

```    
capi-arcus-red-vars.sh:

#! /bin/bash

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
export OPENSTACK_CLOUD_CACERT_B64=$( cat arcus-openstack-hpc-cam-ac-uk.pem | b64encode )
export OPENSTACK_FAILURE_DOMAIN=nova
export OPENSTACK_EXTERNAL_NETWORK_ID=57add367-d205-4030-a929-d75617a7c63e
export OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR=vm.v1.small
export OPENSTACK_NODE_MACHINE_FLAVOR=gaia.vm.cclake.26vcpu
export OPENSTACK_IMAGE_NAME=Ubuntu-Jammy-22.04-20240514-kube-1.30.2
export OPENSTACK_SSH_KEY_NAME=iris-malcolm-kube-test-keypair
export OPENSTACK_DNS_NAMESERVERS=8.8.8.8

export KUBERNETES_VERSION=1.30.2

# optional
export CLUSTER_NAME=iris-gaia-red
export CONTROL_PLANE_MACHINE_COUNT=3
export WORKER_MACHINE_COUNT=4
```

Source the above file to populate the environment variables:
```
source capi-arcus-red-vars.sh
```

To interact with the management cluster, ensure that you are using the correct kubeconfig:
```
export KUBECONFIG=/home/rocky/openstack/k8sdir/config
```

## Create ClusterAPI config

generate a template file for the new cluster using the environment variables we set
capi-red.yaml will be an openstack-specific, project specific template file for building a new k8s cluster
Note this does not actually create a cluster, just a new template for building a cluster

clusterctl generate cluster iris-gaia-red > capi-red.yaml

Warning! Note that we can't check the generated yaml file into public github, as it contains (base64-encoded) access credentials for OpenStack

The DNS configuration isn't required although the generate script insists that the environment variable is set. 
You can remove the dns server reference from the config yaml ("dnsNameservers", see below), if not required. (See above note about BSC)

Specify the loadbalancer provider `ovn`in capi-red.yaml:

```
kind: OpenStackCluster
metadata:
  name: iris-gaia-red
  namespace: default
spec:
  apiServerLoadBalancer:
    enabled: true
    provider: ovn
  ...
```

By default ClusterAPI will try to create a new private network for the kubernetes cluster.  
We don't always want this. For example, if the network needs to talk to other services that we haven't configured in the template (such as ceph), we may want to use an existing network.  
In the generated template, a section "managedSubnets" will appear under "OpenStackCluster". Remove the definition of cluster.managedSubnets and instead use cluster.network to specify an existing network. For example: 

```
kind: OpenStackCluster
metadata:
  name: iris-gaia-red
  namespace: default
spec:
  ...
  network:
    filter:
      name: kubernetes-bootstrap-network
```

```
managedSubnets:
  - cidr: 10.6.0.0/24
    dnsNameservers:
    - 84.88.52.35
```


If we are building a new network, the value we specified for the dns name server is injected via the value for dnsNameservers.
The behaviour here appears to be system-dependent.
On Arcus, the value we set appears to be ignored
On BSC, the value, if supplied, is used directly and must be correct. However, if dnsNameservers is deleted from the config file, the correct dns name server is used by default.

Probably a good idea to have fairly large root volumes on our nodes; kubernetes seems to want to fill these fast.  
Set rootVolume in our templates in the following places:

```
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackMachineTemplate
metadata:
  name: iris-gaia-red-ceph-control-plane
  namespace: default
spec:
  template:
    spec:
      flavor: gaia.vm.cclake.4vcpu
      image:
        filter:
          name: Ubuntu-Jammy-22.04-20240514-kube-1.30.2
      sshKeyName: iris-malcolm-kube-test-keypair
      rootVolume:
        sizeGiB: 100
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackMachineTemplate
metadata:
  name: iris-gaia-red-ceph-md-0
  namespace: default
spec:
  template:
    spec:
      flavor: gaia.vm.cclake.26vcpu
      image:
        filter:
          name: Ubuntu-Jammy-22.04-20240514-kube-1.30.2
      sshKeyName: iris-malcolm-kube-test-keypair
      rootVolume:
        sizeGiB: 200
```

## Create cluster
Use the management cluster to actually build the new cluster, in our target environment, using the image that we prebuilt earlier in the target project.

```
kubectl apply -f capi-red.yaml 
```

## Check progress

```
export CLUSTER_NAME=iris-gaia-red
clusterctl describe cluster ${CLUSTER_NAME}
```

Once the first machines in the control plane have been created:

Download kubeconfig:

```
clusterctl get kubeconfig ${CLUSTER_NAME} > ${CLUSTER_NAME}.kubeconfig
```

## Complete setup

The cluster will not complete until the network configuration is created.

Install Calico CNI
```
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml -O
kubectl --kubeconfig=${CLUSTER_NAME}.kubeconfig apply -f calico.yaml 
```

Get network id of the private network of the cluster. The name starts with `k8s-clusterapi-`.
Get this from the Horizon GUI, or from the openstack client
(If we specified an existing network, get its ID instead)
Note that if we use an existing network, the configuration file only needs to be edited once, as the network ID will be fixed unless the network is deleted / recreated

Create the Openstack cloud controller configuration `appcred-iris-gaia-red.conf`, add the application credentials and the private network id.
This file will be used to create a kubernetes secret, which will then be used by the system setup 
On Arcus, we just use the default load balancer, amphora.

```
[Global]
auth-url=https://arcus.openstack.hpc.cam.ac.uk:5000
region="RegionOne"
application-credential-id="****"
application-credential-secret="****"

[LoadBalancer]
use-octavia=true
floating-network-id=d5560abe-c5d5-4653-a2f7-59636448f8fe
network-id=34de53cc-5b49-489b-9d02-93a31ab7812f
```

Finish network setup and install the Openstack cloud controller to the cluster.

```
kubectl --kubeconfig=${CLUSTER_NAME}.kubeconfig create secret -n kube-system generic cloud-config --from-file=cloud.conf=appcred-iris-gaia-red.conf
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-roles.yaml
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-role-bindings.yaml
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml                                                                       
```

Now the cluster setup completes.
Watch progress
```
clusterctl describe cluster ${CLUSTER_NAME}
```

The cluster initialises with no available storage classes, therefore applications cannot immediately be deployed.  
We assume OpenStack systems will always provide a Cinder storage service, so install the Cinder storage driver into our new cluster.

# Install cinder driver
Install the cinder helm chart

Edit cinder-values.yaml to match our deployed cluster. We point it at the secret we already created during the calico installation

```
secret:
  enabled: true
  name: cloud-config
```

# now deploy into our cluster
helm install --namespace=kube-system -f cinder-values.yaml --kubeconfig=./${CLUSTER_NAME}.kubeconfig cinder-csi cpo/openstack-cinder-csi

# verify the storage classes were created
````
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get storageclass
NAME                             PROVISIONER                       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
csi-cinder-sc-delete             cinder.csi.openstack.org          Delete          Immediate           true                   11d
csi-cinder-sc-retain             cinder.csi.openstack.org          Retain          Immediate           true                   11d
````


# Network configuration
If we specified an already-existing network in our template, we assume that the network has already had all the necessary configuration applied.  
If we didn't specify a network, we need to do some work in the Horizon GUI to connect our generated network to the CEPHFS network.
Our generated network will have a name k8s-clusterapi-cluster-default-<$CLUSTER_NAME> 

In Horizon:
Cephfs router -> Add New Interface -> select k8s-clusterapi-cluster-default-iris-gaia-red, add unused IP address e.g. 10.6.0.10
Networks -> select k8s-clusterapi-cluster-default-iris-gaia-red-> Edit Subnet -> Subnet Details.  Added host route 10.4.200.0/24,10.6.0.10
Add a new bastion host VM on k8s-clusterapi-cluster-default-iris-gaia-red network, add new floating ip address to permit ssh access
Log into bastion host to access kubernetes worker nodes 
On each node, as root run sudo ip route add 10.4.200.0/24 via 10.6.0.10
(We need to manually apply the routing on each node as the routing is normally only applied on VM creation)

Note: it should be possible to automate this through the ClusterAPI template, but still work in progress for now ...

# mount data shares 
At this point our cluster is ready to use. However, we need to be able to access the GAIA DR3 (and potentially other) data from our services.  

If we used a pre-existing network already configured to use the site-specific storage service network, and configured mount instructions in the worker template, then we shouldn't have anything further to do to access the data. Otherwise, we have some work to do in configuring routers and manually mounting services. 

The following instructions are for Arcus. Other sites will have different requirements.   
On the arcus deployment, data is held in a separate project ("iris-gaia-data") within the same physical hardware.  
In the Horizon GUI, select iris-gaia-data in the project list, then navigate to "shares".  
Identify the required data share, and note the share path and the associated cephx access rule and key.
In Horizon, if one doesn't already exist, create a bastion VM on the same network as the kubernetes cluster, and assign a public floating ip address to allow ssh access.
Log into the bastion VM, and log into each of the worker nodes.
Note that ceph is very fussy about consistent naming throughout. The name of the keyring file must be consistent with the name of the access rule ("grants access to") itself.
Do the following on each worker node, for each data share that we want to mount (access via bastion host).
ceph.conf file shown here for ceph on Arcus. Will be different for other systems.


```
# apt update; apt dist-upgrade -y;  apt-get install ceph-common -y
# vim /etc/ceph/ceph.conf
# cat /etc/ceph/ceph.conf
[global]
fsid = a900cf30-f8a3-42bf-98d6-af7ce92f1a1a
mon_host = [v2:10.4.200.13:3300/0,v1:10.4.200.13:6789/0] [v2:10.4.200.9:3300/0,v1:10.4.200.9:6789/0] [v2:10.4.200.17:3300/0,v1:10.4.200.17:6789/0] [v2:10.4.200.26:3300/0,v1:10.4.200.26:6789/0] [v2:10.4.200.25:3300/0,v1:10.4.200.25:6789/0]


# Provision the Manila-generated CephX key
root@pfb29-test:~# vim ceph.client.dr3_data_share.keyring
root@pfb29-test:~# chmod 0600 ceph.client.dr3_data_share.keyring 
root@pfb29-test:~# cat ceph.client.dr3_data_share.keyring 
[client.dr3_data_share]
	key = $REDACTED


# Provision the Manila-generated export path to an env-var, make client mountpoint directory
# here, EXPORT_PATH is the data share path shown in Horizon for the share
root@pfb29-test:~# export EXPORT_PATH="10.4.200.9:6789,10.4.200.13:6789,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/fa5309a4-1b69-4713-b298-c8d7a479f86f/d53177c6-c45c-4583-9947-d50ab931445c"
root@pfb29-test:~# mkdir -p /mnt/dr3_data_share


# Mount and stat the CephFS share
root@pfb29-test:~# mount -t ceph $EXPORT_PATH /mnt/dr3_data_share -o name=dr3_data_share
root@pfb29-test:~# df -h -t ceph
Filesystem                                                                                                                                                                       Size  Used Avail Use% Mounted on
10.4.200.9:6789,10.4.200.13:6789,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/fa5309a4-1b69-4713-b298-c8d7a479f86f/d53177c6-c45c-4583-9947-d50ab931445c   10G     0   10G   0% /mnt/cephfs
```

Doing this for each machine in our cluster is clearly not ideal. The ClusterAPI template allows us to specify extended configuration information as follows.  
Here, before worker machines join our cluster, we install and configure ceph, and create keyring files for our shares, and create mount entries in /etc/fstab  
Then, we force a remount as the worker joins the cluster. (This does assume the ceph network has already been configured, otherwise the worker will likely fail).

```
kind: KubeadmConfigTemplate
metadata:
  name: iris-gaia-red-ceph-md-0
  namespace: default
spec:
  template:
    spec:
      mounts: []
      preKubeadmCommands: ["apt-get update;", "apt-get install ceph-common -y;", "mkdir -p /mnt/kubernetes_scratch_share", "echo 10.4.200.9:6789,10.4.200.13:67
89,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/280b44fc-d423-4496-8fb8-79bfc1f58b97/35e407e9-a34b-4c64-b480-3380002d64f8 /mnt/kubernet
es_scratch_share ceph name=kubernetes-scratch-share,noatime,_netdev 0 2 >> /etc/fstab"]
      files:
      - path: /etc/ceph/ceph.conf
        content: |
              [global]
              fsid = a900cf30-f8a3-42bf-98d6-af7ce92f1a1a
              mon_host = [v2:10.4.200.13:3300/0,v1:10.4.200.13:6789/0] [v2:10.4.200.9:3300/0,v1:10.4.200.9:6789/0] [v2:10.4.200.17:3300/0,v1:10.4.200.17:6789/0
] [v2:10.4.200.26:3300/0,v1:10.4.200.26:6789/0] [v2:10.4.200.25:3300/0,v1:10.4.200.25:6789/0]

      - path: /etc/ceph/ceph.client.kubernetes-scratch-share.keyring
        content: |
          [client.kubernetes-scratch-share]
          key = REDACTED

      postKubeadmCommands: ["sudo mount -a"]

      joinConfiguration:
        nodeRegistration:
          kubeletExtraArgs:
            cloud-provider: external
            provider-id: openstack:///'{{ instance_id }}'
          name: '{{ local_hostname }}'
```

(It should be possible to configure other storage types, such as nfs, in a similar fashion)  

Now that all our workers have the data share mounted, we can access it via a hostPath mount from our pods, eg

```
spec:
  volumes:
    - name: mount-this
      hostPath: 
        path: /mnt/dr3_data_share
        type: Directory
  containers:
  - volumeMounts:
    - mountPath: /mnt/dr3_data_share
      name: mount-this
      readOnly: true
```

The (read-only) DR3 data should now be accessible in the pod at /mnt/dr3_data_share

## rescale cluster

The management cluster can be used to view active workers and rescale a running worker cluster, via the machinedeployments class.
e.g.

```
$ kubectl get machinedeployment
NAME                      CLUSTER              REPLICAS   READY   UPDATED   UNAVAILABLE   PHASE     AGE    VERSION
bsc-gaia-md-0             bsc-gaia             3          3       3         0             Running   25h    v1.30.2
iris-gaia-red-ceph-md-0   iris-gaia-red-ceph   4          4       4         0             Running   22d    v1.30.2
iris-gaia-red-demo-md-0   iris-gaia-red-demo   7          7       7         0             Running   6d2h   v1.30.2
```

Increase number of workers for one of our clusters

```
$ kubectl scale machinedeployment iris-gaia-red-demo-md-0 --replicas=9
```

If we specified the storage mounts in our cluster template, then these should automatically be applied when the new worker joins the cluster.  
However, if we created the mounts manually, this will need to be repeated manually for the new worker.

# Deleting a cluster

Before deleting a cluster, note that CAPI struggles to delete resources that were created within the cluster, such as services, load balancers etc. 
Applications should be deleted in reverse order of creation before trying to delete the cluster, especially those managing load balancers and floating ip addresses. 
This may be useful in making deletions cleaner, haven't tried it yet ... https://github.com/azimuth-cloud/cluster-api-janitor-openstack

To delete a CAPI-deployed cluster:

```
kubectl delete cluster ${CLUSTER_NAME}
```

Note we don't specify --kubeconfig here, as we are using the management cluster (ie pointed to by ${KUBECONFIG}) to control the cluster teardown

## Manual deletion

Sometimes things don't go smoothly during deployment, particularly when getting up and running at a new site.
The management cluster can get confused about the state of the remote cluster. 
If this happens, easiest way to clean up is to manually delete all the created resources in the target environment, then purge references from the management cluster.
The following classes need to be purged for the failed cluster, in the following order: OpenStackMachines, OpenStackMachineTemplates, OpenStackClusterTemplate

e.g.

```
$ kubectl get openstackmachines
NAME                                     CLUSTER              INSTANCESTATE   READY   PROVIDERID                                          MACHINE                                  AGE
bsc-gaia-control-plane-r94xt             bsc-gaia             ACTIVE          true    openstack:///25a0e44a-f037-4418-a515-cb2da0e4f3ff   bsc-gaia-control-plane-r94xt             25h
bsc-gaia-md-0-xqdtp-52fm7                bsc-gaia             ACTIVE          true    openstack:///dc4a2f10-6277-41e5-a6f6-10ef6278df97   bsc-gaia-md-0-xqdtp-52fm725h

$kubectl delete openstackmachine bsc-gaia-md-0-xqdtp-52fm7
```

Once all resources have been deleted from the management cluster, the cluster itself can be deleted.
To force deletion, it may be necessary to delete the cluster finaliser by editing the clustertemplate object

```
$ kubectl get openstackclusters
NAME                 CLUSTER              READY   NETWORK                                BASTION IP   AGE
bsc-gaia             bsc-gaia             true    b32e99b0-e3f8-4318-b0fb-9fa1ea3d4bf9                25h

$ kubectl edit openstackcluster bsc-gaia (opens config in vim)
replace value for finalisers with [] and save out

# Management cluster failure / deletion

If we lose the management cluster for any reason, its not the end of the world. 
The deployed clusters will still function independently, assuming we have their KUBECONFIG files. 
However, we should do everything to avoid this happening ...


## Manila configuration
On Arcus and Somerville we have access to a Manila service. This effectively acts as a higher level storage service, and supports multiple protocols.
Currently these sites are configured to support ceph via Manila, so we can install the manila storage driver into our cluster.

# First install the ceph csi driver as manila will need it
# followed notes at https://gitlab.developers.cam.ac.uk/pfb29/manila-csi-kubespray

```
helm repo add ceph-csi https://ceph.github.io/csi-charts
helm --kubeconfig=./${CLUSTER_NAME}.kubeconfig install --namespace kube-system ceph-csi-cephfs ceph-csi/ceph-csi-cephfs
```

# install the manila csi driver

manila-values.yaml

```
---
shareProtocols:
  - protocolSelector: CEPHFS
    fsGroupPolicy: None
    fwdNodePluginEndpoint:
      dir: /var/lib/kubelet/plugins/cephfs.csi.ceph.com
      sockFile: csi.sock
```

```
helm  repo add cpo https://kubernetes.github.io/cloud-provider-openstack
helm install --kubeconfig=./${CLUSTER_NAME}.kubeconfig --namespace kube-system manila-csi cpo/openstack-manila-csi -f manila-values.yaml
```

# Create a secret for deploying our manila storage class, assumes we created an access credential in the target OpenStack project with suitable priviledges

secrets.yaml

```
apiVersion: v1
kind: Secret
metadata:
  name: csi-manila-secrets
  namespace: default
stringData:
  # Mandatory
  os-authURL: "https://arcus.openstack.hpc.cam.ac.uk:5000/v3"
  os-region: "RegionOne"

  # Authentication using user credentials
  os-applicationCredentialID: "*****"
  os-applicationCredentialSecret: "*******"
```

```
kubectl apply --kubeconfig=./${CLUSTER_NAME}.kubeconfig -f secrets.yaml
```

# create a manila storage class using the access secret we just created

```

sc.yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-manila-cephfs
provisioner: cephfs.manila.csi.openstack.org
parameters:
  type: ceph01_cephfs # Manila share type
  cephfs-mounter: kernel
  csi.storage.k8s.io/provisioner-secret-name: csi-manila-secrets
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: csi-manila-secrets
  csi.storage.k8s.io/node-stage-secret-namespace: default
  csi.storage.k8s.io/node-publish-secret-name: csi-manila-secrets
  csi.storage.k8s.io/node-publish-secret-namespace: default
```

```
kubectl apply --kubeconfig=./${CLUSTER_NAME}.kubeconfig -f sc.yaml
```

We now have the manila storage driver installed.
We can make this the default storage class, so any user volumes are automatically created as ceph shares instead of cinder volumes

# make manila the default storage class

```
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig patch storageclass csi-manila-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

# list the storage classes in the cluster
```
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get storageclass
NAME                             PROVISIONER                       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
csi-cinder-sc-delete             cinder.csi.openstack.org          Delete          Immediate           true                   12d
csi-cinder-sc-retain             cinder.csi.openstack.org          Retain          Immediate           true                   12d
csi-manila-cephfs (default)      cephfs.manila.csi.openstack.org   Delete          Immediate           false                  5d5
```

At this point our new cluster should be ready to accept kubernetes services in the normal fashion, using the KUBECONFIG file that was generated during the cluster creation.












