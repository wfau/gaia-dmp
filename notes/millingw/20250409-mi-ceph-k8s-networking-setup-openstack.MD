# ClusterAPI Deployment and Networking

When we deploy a ClusterAPI kubernetes cluster into an OpenStack project, we can specify either to use a new network for the cluster, or to use an existing network. 
Often we will want to use other networked services such as CephFS or NFS from our cluster. Generally the network setup to allow our kubernetes service to access these services is non-trivial. 
We can either allow ClusterAPI to create the network, and then apply the additional networking changes to the created network. However, ClusterAPI will attempt to remove the network on cluster teardown, and we end up with a combination of our networking changes being lost, and errors in deleting the network, unless we remove the additional config before tearing down the cluster.  
Alternatively, we can create all of the networking config in advance, and deploy the cluster onto the existing network. On teardown, ClusterAPI will not remove any of the networking.

This guide is in two sections. The first section describes how to manually create a network and configure it for normal use with a router to the wider world. The second section describes how to add ceph connectivity to an existing network, regardless of whether the network was created manually or by ClusterAPI.


## Add new network

In the following, we assume the external internet is present as network 'CUDN-Internet'

Create router for external internet access
Networking -> Routers -> Create Router
Create router 'k8s-cudn-router', select External Network 'CUDN-Internet'

Create a new network as our default kubernetes internal network
Networking -> Create Network 
Specify network name 'k8s-default-network'
Subnet-> Specify unused network range, eg 10.13.0.0/24
Leave Gateway IP blank, will default to eg 10.13.0.1 as we will initially have nothing on the network

Connect our new router to our new network
Networking -> Routers -> 'k8s-cudn-router' -> Interfaces -> 'Add Interface'
Select our new network from the list of networks.
Leave IP Address blank, this will default to the Gateway IP of our new network.  

Create a test VM on the new network, ssh into it and test connectivity to the outside world.


## Add ceph to existing network

The following assumes ceph network configured in the OpenStack project as 'cephfs', address 10.9.0.0
Also assumes kubernetes network already exists, eg 'k8s-clusterapi-cluster-default-iris-gaia-red', either manually created or created via ClusterAPI.

Create a new router, e.g. ceph-k8s-router
Networking->Routers->Create Router
Specify router name, eg ceph-k8s-router
Specify external network 'cephfs'

Add a new interface to the router you just created above.
Networking->Routers->'ceph-k8s-router'-> Add Interface
You should see the existing kubernetes network listed in the 'Subnet' list.
Select it, then specify an IP address for the interface. This should be an unused address on the subnet network
For example, if the kubernetes network is 10.15.0.0, specify 10.15.0.15

Configure a static route on the new router
Network-> Routers -> 'ceph-k8s-router'
Add a static route between the external ceph network and the local ceph network
'Add Static Route' -> Destination CID = 10.4.200.0/24, Next Hop - 10.9.0.1 (the gateway address of the internal ceph network)

On the network, edit the subnet to add a route to the ceph network
Networks -> Network -> 'k8s-clusterapi-cluster-default-iris-gaia-red' -> Subnets (should only be one)
Edit subnet -> Subnet Details -> Host Routes, add 10.4.200.0/24,10.15.0.15 (ie the IP address you specified when setting up the ceph router)


Add a small test VM to the kubernetes network, configuring ssh access and a floating ip address.
ssh to the instance, and test connectivity by pinging the ceph monitor addresses

$ ping 10.4.200.9
PING 10.4.200.9 (10.4.200.9) 56(84) bytes of data.
64 bytes from 10.4.200.9: icmp_seq=1 ttl=62 time=3.54 ms
64 bytes from 10.4.200.9: icmp_seq=2 ttl=62 time=0.402 ms
64 bytes from 10.4.200.9: icmp_seq=3 ttl=62 time=0.444 ms

It may be necessary to restart any VMs, or their networking services, that were already on the k8s network, as they may not pick up the network changes post creation.



## Deleting a network

It's easy to make mistakes when configuring OpenStack networking.  If you want to delete things, you have to delete in the correct order.

To delete a network, first look for any routers attached to the network.
For any attached router, look at the router's interfaces, and delete any interface attached to the network.
If no interfaces remain in the router, the router can be deleted.
In the network, delete each subnet (although should only one).
If there is an error deleting the subnet, check that there are no remaining ports on the subnet, and that it is not still connected to a router.
Once all the subnets have been deleted, it should be possible to delete the network.

## ClusterAPI networking specification

It's out of the scope of this note to talk much about the ClusterAPI cluster specification yaml file, other than to point out the relevant parts for networking.  
The generated ClusterAPI yaml file will contain a Cluster spec block, similar to 

```
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackCluster
metadata:
  name: iris-gaia-red
  namespace: default
spec:
  ** REDACTED **
  managedSubnets:
  - cidr: 10.15.0.0/24
    dnsNameservers:
    - "8.8.8.8"
```

If we retain the 'managedSubnets' block, ClusterAPI will try to create a new network on the specified network range.  
Alternatively, we can remove the 'managedSubnets' block and use a network name filter, and ClusterAPI will try to use an existing network.  

```
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackCluster
metadata:
  name: iris-gaia-red
  namespace: default
spec:
  ** REDACTED **
  network:
    filter:
      name: existing-internal-kubernetes-network

```