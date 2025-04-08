# CEPHFS, OpenStack and Kubernetes

## Overview 
On our two main sites for GAIA DMP (Arcus and Somerville), we are using CephFS for our data storage.  
CephFS is fairly standard for large scientific data / supercomputing sites. 
CephFS is run as a separate cluster on its own network.  
Usually we can expect 3 monitor IP addresses for accessing a CephFS service. 

## Create or view a ceph share
For an OpenStack environment we normally expect the ceph service to be configured and available via Horizon  
Project -> Shares -> list of shares we can see  
New ceph shares can be created via Create Share -> 'Share Protocol' = CephFS  
For Arcus, our main Ceph shares are managed from within the 'data' project
To give access to a Ceph share, you need to create a credential.  
Project -> Shares -> Click on share name -> Manage Rules -> Add Rule  
In the form, select 'Access Type' = cephx  
Decide if the credential should give read / write or read-only access  
'Access To' is the name of the share.  
There's a bit of weirdness here. We can only use '_' characters in the name, as the ceph client will object to '-' characters.  
So for example if our share name is 'dr3-gaia-source-demo', then 'Access To' must be 'dr3_gaia_source_demo'
Saving the form will then show a new access key listed against the share.  
Ceph access keys should never be committed to github, as they are equivalent to a password  

## Use a ceph share in a kubernetes cluster 
To use a ceph share within a cluster, we need to mount the share identically into each worker VM in our cluster.  
The network that the cluster uses must be configured with access to the CephFS network. The network configuration is non-trivial, and for the purposes of these notes, assumed to have already been completed.  
On each worker VM in our cluster, we need to install the ceph client software, then make directories for each share that we want to mount (ceph_example_share for the purposes of demonstration)    

```
apt-get update
apt-get install ceph-common -y 
mkdir -p /mnt/ceph_example_share
```

Installing the ceph client should create a ceph directory, /etc/ceph  
Create a ceph config file, /etc/ceph/ceph.conf, with the details of the ceph service. These are correct for arcus, but you will need to ask the admins for other systems  

```
[global]
   fsid = a900cf30-f8a3-42bf-98d6-af7ce92f1a1a
   mon_host = [v2:10.4.200.13:3300/0,v1:10.4.200.13:6789/0] [v2:10.4.200.9:3300/0,v1:10.4.200.9:6789/0] [v2:10.4.200.17:3300/0,v1:10.4.200.17:6789/0] [v2:10.4.200.26:3300/0,v1:10.4.200.26:6789/0] [v2:10.4.200.25:3300/0,v1:10.4.200.25:6789/0]

```

Ping the monitor addresses to test that you have connectivity to the ceph service. If ping doesn't return anything, ask the system admins for help.

'''
ping 10.4.200.13
ping 10.4.200.9
ping 10.4.200.17
'''

We then need to use our Ceph share credential to allow the ceph share to be mounted. 
Create a file /etc/ceph/ceph.client.ceph-example-share.keyring

```
[client.ceph-example-share]
    key = <access key from Horizon>

```

We then need the full path to the Ceph share, you can find this in Horizon by clicking Project -> Share -> Shares -> <share name>  
The value we need is Export Locations -> Path. This will be a long url, similar to 10.4.200.9:6789,10.4.200.13:6789,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/280b44fc-d423-4496-8fb8-79bfc1f58b97/35e407e9-a34b-4c64-b480-3380002d64f8

We can now mount the ceph share to the VM

```
export EXPORT_PATH=10.4.200.9:6789,10.4.200.13:6789,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/280b44fc-d423-4496-8fb8-79bfc1f58b97/35e407e9-a34b-4c64-b480-3380002d64f8
sudo mount -t ceph $EXPORT_PATH /mnt/ceph_example_share -o name=ceph-example-share

```

Unfortunately ceph error output is minimal and a bit misleading. Errors are usually due to connectivity issues, mismatches in keynames and keyring filenames.  
It can be difficult to figure out what's going wrong till you've used it for a while.  

Test that the mount has been successful by listing the mounted directory and checking the contents

Note that the mount will be lost if the VM is rebooted. An alternative is to add an entry to /etc/fstab, so that the directory will automatically be remounted on reboot  

```
echo $EXPORT_PATH     /mnt/ceph-example-share    ceph    name=ceph-example-share,noatime,_netdev    0       2 >> /etc/fstab
sudo mount -a
```

Note that this will have to be repeated for each ceph share that we want to mount, and the process repeated for each VM.


## Automation via ClusterAPI 
ClusterAPI will actually let us automate most of this at VM creation time, assuming the cluster is being created on a network which has already been configured with access to a ceph network.  
In our cluster specification yaml file, we can add instructions to install the ceph client, configure the keyring files and populate /etc/fstab.  

For example:

```
apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: KubeadmConfigTemplate
metadata:
  name: iris-gaia-green-md-0
  namespace: default
spec:
  template:
    spec:
      preKubeadmCommands: ["apt-get update;apt-get install ceph-common -y",
        "mkdir /mnt/edr3",
        "mkdir /mnt/dr3_data_share",
        "echo 10.4.200.9:6789,10.4.200.13:6789,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/5e74d2f7-dba9-40aa-ab90-526c8d0d58e5     /mnt/edr3    ceph    name=aglais-data-gaia
-edr3-2048-ro,noatime,_netdev    0       2 >> /etc/fstab",
        "echo 10.4.200.9:6789,10.4.200.13:6789,10.4.200.17:6789,10.4.200.25:6789,10.4.200.26:6789:/volumes/_nogroup/5875b16a-3fd1-489e-a342-d50548e4e522     /mnt/dr3_data_share    ceph    name=aglais
-data-gaia-dr3-2048-new-ro,noatime,_netdev    0       2 >> /etc/fstab"
       ]
      postKubeadmCommands: ["sudo mount -a"]
      files:
      - path: /etc/ceph/ceph.conf
        content: |
              [global]
              fsid = a900cf30-f8a3-42bf-98d6-af7ce92f1a1a
              mon_host = [v2:10.4.200.13:3300/0,v1:10.4.200.13:6789/0] [v2:10.4.200.9:3300/0,v1:10.4.200.9:6789/0] [v2:10.4.200.17:3300/0,v1:10.4.200.17:6789/0] [v2:10.4.200.26:3300/0,v1:10.4.200.26:
6789/0] [v2:10.4.200.25:3300/0,v1:10.4.200.25:6789/0]
      - path: /etc/ceph/ceph.client.aglais-data-gaia-edr3-2048-ro.keyring
        content: |
          [client.aglais-data-gaia-edr3-2048-ro]
            key = **REDACTED**
      - path: /etc/ceph/ceph.client.aglais-data-gaia-dr3-2048-new-ro.keyring
        content: |
          [client.aglais-data-gaia-dr3-2048-new-ro]
            key = **REDACTED**
```

Commands specified in preKubeadmCommands are run after the worker VM has booted up, but before the VM joins the cluster.  
'Files' can be used to specify the content of files to be created on the worker VM.  
postKubeadmCommands can be used to run commands after the VM joins the cluster.  
In the above, we install the ceph client software, then make 2 directories that will be used to mount ceph shares.  
Under 'files' we populate the ceph configuration with the monitor addresses, then create keyring files for each ceph mount.  
We echo the mount details of the ceph shares to /etc/fstab  
The above will all execute before the VM joins the kubernetes cluster.  
On joining the cluster, we run 'sudo mount -a' via postKubeadmCommands, which runs the actual mounting to the VM.  
As our mounts are specified in /etc/fstab, they will be restored in the event of the VM being rebooted.

## Other storage types
At BSC, we expect to access the datasets via an NFS network.  
We can take a similar approach to mounting the data into our worker VMs. 
Here we assume we are installing the cluster to a network which has been preconfigured with access to the NFS network.  

```
spec:
  template:
    spec:
      files: []
      preKubeadmCommands: [
        "apt-get update;", "apt-get install nfs-common -y;",
        "mkdir -p /mnt/nfs/shared",
        "echo 192.168.0.15:/mnt/nfs/shared    /mnt/nfs/shared    nfs    defaults    0 0 >> /etc/fstab"]
      joinConfiguration:
        nodeRegistration:
          kubeletExtraArgs:
            cloud-provider: external
            provider-id: openstack:///'{{ instance_id }}'
          name: '{{ local_hostname }}'
      postKubeadmCommands: ["sudo mount -a"]
```

Here we install the nfs client software into our VM, make a mount directory, then create an nfs mount specification in /etc/fstab  
Finally we remount everything to pick up our changes to /etc/fstab  


