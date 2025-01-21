## ClusterAPI build scripts  

Building a cluster involves multiple steps and lots of configuration files.  
Each site that we deploy to is likely to have different storage configurations, networks, credentials  
Here I am trying to collect together the set of config files for each site that we are deploying to, and using a single deployment script, build_my_cluster.sh  
build_my_cluster.sh assumes that all preparatory work has already been done, ie a management cluster has been created, compatible ClusterAPI images have been created and tested in the target OpenStack environments, and a cluster template has been generated.
The following tools must be installed prior to running the script: kubectl, clusterctl, openstack cli

The script reads a config file, which sets all the necessary environment variables that the script expects:

export KUBECONFIG=<path to the KUBECONFIG file for our ClusterAPI management cluster>
export CLUSTER_NAME=<name of the cluster we are deploying, must match the cluster specification file>
export CLUSTER_SPECIFICATION_FILE=<generated ClusterAPI specification file, contains all the credentials and templates for our cluster creation>
export CLUSTER_CREDENTIAL_FILE=<path to configuration file containing credentials for target OpenStack project and load balancer / networking configuration>
export CINDER_SECRETS_FILE=<path to credentials file for installing the Cinder storage driver into our cluster (we assume OpenStack will always have CinderAvailable  

The following is Manila-specific. On Arcus and Somerville we have the Manila service available, which gives us access to ceph. Other sites may not provide this, in which case set USE_MANILA=false

USE_MANILA=true
MANILA_PROTOCOLS_FILE=values.yaml
MANILA_SECRETS_FILE=secrets.yaml
MANILA_STORAGE_CLASS_FILE=sc.yaml
DEFAULT_STORAGE_CLASS=manila

Running ./build_my_cluster.sh will build a new cluster in the targeted OpenStack project.  
The following stages are run:
  Build the initial cluster
  Wait for the initial control plane to become available
  Wait for the basic service to start
  Install the control plane software (Calico)
  Wait for initialisation
  Install cinder storage driver
  (Optionally install Manila storage driver)
  Wait for all workers to join

Cluster creation can be monitored with clusterctl, ie clusterctl describe cluster $CLUSTER_NAME

Note that a cluster may be ready for use before all workers are ready; the script may loop indefinitely if the target project can't provide the requested number of workers.

The resulting cluster and KUBECONFIG file can then be used to install kubernetes services in the usual fashion.
  
The intention is to maintain a set of production scripts for each deployment site, with a separate master configuration file for each site to be sourced by the build script.

