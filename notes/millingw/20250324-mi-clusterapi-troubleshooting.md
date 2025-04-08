# ClusterAPI Trouble shooting

Every OpenStack site that we deploy to has its own differences, such as networking setup, load balancers, storage systems etc.  
This means that we have to have a set of scripts per site. There is a lot to go wrong!  

## OpenStack Cloud File and Kubernetes cloud-config Secret

The OpenStack clouds.yaml and clouds.rc files have slightly different formatting from the cloud-config secret that ClusterAPI expects to read.  
Unfortunately, if the formatting is incorrect, the ClusterAPI process fails but then swallows the error, leaving you wondering why nothing is working.  
This usually manifests itself as having a cluster that fails to complete building and / or no IP addresses for nodes, when viewed with "kubectl get nodes"  

The cloud-config secret file *must* have the following formatting, otherwise the cluster will fail. You can't just copy and paste from the clouds.yaml file, as the formatting is different!  

```
[Global]
auth-url=https://arcus.openstack.hpc.cam.ac.uk:5000
region="RegionOne"
application-credential-id="REDACTED"
application-credential-secret="REDACTED"

[LoadBalancer]
use-octavia=true
floating-network-id=57add367-d205-4030-a929-d75617a7c63e
network-id=7d376fd5-520c-488c-9c03-088e40737c23

```

Compare this with the equivalent clouds.yaml file. Note that copying over ":" and "_" characters to the cloud-config file will cause the cluster to fail!  

```
 iris-gaia-blue:
    auth:
      auth_url: https://arcus.openstack.hpc.cam.ac.uk:5000
      application_credential_id: "REDACTED"
      application_credential_secret: "REDACTED"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
    auth_type: "v3applicationcredential"
```

If there is a config error, you may see something similar to the following in the cloud controller manager logs:  

```
2025-03-19T16:14:30.494972446Z stdout F I0319 16:14:30.494468      12 serving.go:386] Generated self-signed cert in-memory
2025-03-19T16:14:30.916391181Z stdout F I0319 16:14:30.916234      12 serving.go:386] Generated self-signed cert in-memory
2025-03-19T16:14:30.917204754Z stdout F W0319 16:14:30.916375      12 client_config.go:667] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
2025-03-19T16:14:32.386099079Z stdout F W0319 16:14:32.385889      12 openstack.go:184] failed to read config: 3:9: illegal character U+003A ':'
2025-03-19T16:14:32.386140005Z stdout F F0319 16:14:32.385936      12 main.go:71] Cloud provider could not be initialized: could not init cloud provider "openstack": 3:9: illegal character U+003A ':
'
```

You will need to fix this as nothing will work properly beyond this point!

Basic config errors like this will cause the basic services such as the controller manager pod and networking to fail to start, and the kubernetes logging effectively becomes useless as everything assumes a functional kubernetes network is present.  
If the cloud controller pod and networking have failed to start correctly, you will likely see the following a lot in error messages:  

```
Error from server: no preferred addresses found; known addresses: []
```

There will probably also be a lot of noise about etcd failures, but these are likely a red herring as the underlying issue is likely the networking.  

## Load balancers 

Our understanding is that standard OpenStack setup uses Octavia with ovn. Some sites use Octavia with amphora. BSC currently has no load balancer.  
Each site needs a separate configuration, pay attention to the load balancer use in the yaml file and the cloud-config file  
Using the wrong combination for a given site will result in the cluster failing.  

## Debugging

If a cluster fails to deploy correctly, there may not be that much information directly available in the cluster pods. 
If the basic service has failed to start, the intial cloud controller manager pod will likely be sitting in CrashBackoffLoop state, and coredns pods will be sitting in Pending.  
If that's what you can see, its likely the fault is in the cloud-config secret, as described above.  

Errors in the initial startup are not handled well. If you see complaints about empty IP addresses, its likely the network service has failed to start correctly.  

Check you can manually build instances in the target OpenStack instance before trying to do a ClusterAPI deploy, to ensure that you are using a valid image and flavour combination for that system.  
If you use an invalid combination, the best place to look for logs is the capo-controller-manager pod in the capo-system namespace in the management cluster.  

Sometimes the best place to look for errors is on the control node VM itself. 
If you get a single control plane VM and nothing else, then set up ssh access into the VM and login.  
Detailed output from the pods can be found in the directories under /var/log/containers or /var/log/pods.  
If something has gone fundamentally wrong during startup, useful information is more likely to be found here than via kubectl logs <pod>







