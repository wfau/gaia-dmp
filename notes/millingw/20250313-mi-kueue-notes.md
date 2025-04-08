# Kueue notes:


Cluster Queues schedule the actual jobs.  
Local queues are created in a specific namespace, and point at a specific cluster queue that actually executes the job.   
Users must have access to the namespace that the local queue lives in, in order to be able to submit a job.  
 
Tested on ClusterAPI-generated cluster on Arcus red. 4x 240GB, 74 VCPU

Installed kueue following notes here: https://kueue.sigs.k8s.io/docs/installation/#install-by-kubectl

```
$ kubectl apply --kubeconfig=./${CLUSTER_NAME}.kubeconfig --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.2/manifests.yaml
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig wait deploy/kueue-controller-manager -nkueue-system --for=condition=available --timeout=5m
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.2/prometheus.yaml
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.2/visibility-apf.yaml
```

Create a test cluster queue

```
test_queue.yaml

apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "cluster-queue"
spec:
  namespaceSelector: {} # match all.
  resourceGroups:
  - coveredResources: ["cpu", "memory", "pods"]
    flavors:
    - name: "default-flavor"
      resources:
      - name: "cpu"
        nominalQuota: 148
      - name: "memory"
        nominalQuota: 480Gi
      - name: "pods"
        nominalQuota: 32
```

```
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f test_queue.yaml
clusterqueue.kueue.x-k8s.io/cluster-queue configured
```

The queue needs resources that define the underlying nodes.  
If we're running in a homogeneous environment, we can just create and reference a default resource

```
default_resource.yaml

apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor
```

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f simple_resource.yaml
```

Examine the queue we just created

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig describe clusterqueue.kueue.x-k8s.io/cluster-queue
Name:         cluster-queue
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  kueue.x-k8s.io/v1beta1
Kind:         ClusterQueue
Metadata:
  Creation Timestamp:  2025-03-06T15:44:32Z
  Finalizers:
    kueue.x-k8s.io/resource-in-use
  Generation:        4
  Resource Version:  1974890
  UID:               326208d3-acbf-4d79-804d-70f76a86873e
Spec:
  Flavor Fungibility:
    When Can Borrow:   Borrow
    When Can Preempt:  TryNextFlavor
  Namespace Selector:
  Preemption:
    Borrow Within Cohort:
      Policy:               Never
    Reclaim Within Cohort:  Never
    Within Cluster Queue:   Never
  Queueing Strategy:        BestEffortFIFO
  Resource Groups:
    Covered Resources:
      cpu
      memory
      pods
    Flavors:
      Name:  default-flavor
      Resources:
        Name:           cpu
        Nominal Quota:  148
        Name:           memory
        Nominal Quota:  480Gi
        Name:           pods
        Nominal Quota:  32
  Stop Policy:          None
Status:
  Admitted Workloads:  0
  Conditions:
    Last Transition Time:  2025-03-07T13:29:49Z
    Message:               Can admit new workloads
    Observed Generation:   4
    Reason:                Ready
    Status:                True
    Type:                  Active
  Flavors Reservation:
    Name:  default-flavor
    Resources:
      Borrowed:  0
      Name:      cpu
      Total:     0
      Borrowed:  0
      Name:      memory
      Total:     0
      Borrowed:  0
      Name:      pods
      Total:     0
  Flavors Usage:
    Name:  default-flavor
    Resources:
      Borrowed:         0
      Name:             cpu
      Total:            0
      Borrowed:         0
      Name:             memory
      Total:            0
      Borrowed:         0
      Name:             pods
      Total:            0
  Pending Workloads:    0
  Reserving Workloads:  0
Events:                 <none>
```

We've created a simple cluster queue, now we need local queues in order to actually submit and run jobs.   
Lets create two namespaces, test and production

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create namespace test
namespace/test created
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create namespace production
namespace/production created
```

And create matching local queues, test-local-queue and production-local-queue

```
test_local_queue.yaml

apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: test
  name: test-local-queue
spec:
  clusterQueue: cluster-queue
```

```
production_local_queue.yaml

apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: production
  name: production-local-queue
spec:
  clusterQueue: cluster-queue
```

```  
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f test_local_queue.yaml
localqueue.kueue.x-k8s.io/test-local-queue created

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f production_local_queue.yaml
localqueue.kueue.x-k8s.io/production-local-queue created
```

As we've created these in specific namespaces, they should only list by namespace

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueues
No resources found in default namespace.
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueues -n test
NAME               CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
test-local-queue   cluster-queue   0                   0
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueues -n production
NAME                     CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
production-local-queue   cluster-queue   0                   0
```

Now run a simple job to test and production

```
simple_test_job.yaml

apiVersion: batch/v1
kind: Job
metadata:
  generateName: sample-test-job-
  namespace: test
  labels:
    kueue.x-k8s.io/queue-name: test-local-queue
spec:
  parallelism: 3
  completions: 3
  suspend: true
  template:
    spec:
      containers:
      - name: dummy-job
        image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
        args: ["60s"]
        resources:
          requests:
            cpu: 6
            memory: "200Mi"
      restartPolicy: Never
```
```
 simple_production_job.yaml
 
 apiVersion: batch/v1
 kind: Job
 metadata:
   generateName: sample-production-job-
   namespace: production
   labels:
     kueue.x-k8s.io/queue-name: production-local-queue
 spec:
   parallelism: 3
   completions: 3
   suspend: true
   template:
     spec:
       containers:
       - name: dummy-job
         image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
         args: ["200s"]
         resources:
           requests:
             cpu: 6
             memory: "200Mi"
      restartPolicy: Never
```

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create -f simple-production-job.yaml
job.batch/sample-production-job-v5jw7 created
(openstack) [rocky@gaia-dataset-01 openstack]$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create -f simple-test-job.yaml
job.batch/sample-test-job-4bzjn created

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get workloads -n test
NAME                              QUEUE              RESERVED IN     ADMITTED   FINISHED   AGE
job-sample-test-job-4bzjn-4b0fd   test-local-queue   cluster-queue   True                  8s

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueues -n test
NAME               CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
test-local-queue   cluster-queue   0                   1

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueues -n production
NAME                     CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
production-local-queue   cluster-queue   0                   1

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get workloads -n production
NAME                                    QUEUE                    RESERVED IN     ADMITTED   FINISHED   AGE
job-sample-production-job-v5jw7-bd86a   production-local-queue   cluster-queue   True                  2m58s
```

Eventually:

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get workloads -n production
NAME                                    QUEUE                    RESERVED IN     ADMITTED   FINISHED   AGE
job-sample-production-job-v5jw7-bd86a   production-local-queue   cluster-queue   True       True       4m45s

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get workloads -n test
NAME                              QUEUE              RESERVED IN     ADMITTED   FINISHED   AGE
job-sample-test-job-4bzjn-4b0fd   test-local-queue   cluster-queue   True       True       5m7s
```

Note that default behaviour is that limits-busting jobs are held indefinitely in a PENDING state, rather than being rejected. 
Presumably in the hope that additional resources might become available, eg if using a cluster auto scaler.
TODO, establish how to reject too large jobs rather than have them sitting as PENDING; suggestion to use a policy engine but this adds whole new scale of complexity

Example:

```
big_job.yaml

apiVersion: batch/v1
kind: Job
metadata:
  generateName: sample-production-job-
  namespace: production
  labels:
    kueue.x-k8s.io/queue-name: production-local-queue
spec:
  parallelism: 3
  completions: 3
  suspend: true
  template:
    spec:
      containers:
      - name: dummy-job
        image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
        args: ["200s"]
        resources:
          requests:
            cpu: 20000
            memory: "200Mi"
      restartPolicy: Never
```
```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create -f big_job.yaml
job.batch/sample-production-job-7wzqh created

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueue -n production
NAME                     CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
production-local-queue   cluster-queue   1                   0

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get workloads -n production
NAME                                    QUEUE                    RESERVED IN     ADMITTED   FINISHED   AGE
job-sample-production-job-7wzqh-a13ae   production-local-queue                                         3m19s

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig describe workload job-sample-production-job-7wzqh-a13ae -n production
...
Status:
  Conditions:
    Last Transition Time:  2025-03-12T12:55:08Z
    Message:               couldn't assign flavors to pod set main: insufficient quota for cpu in flavor default-flavor, request > maximum capacity (60k > 148)
    Observed Generation:   1
    Reason:                Pending
    Status:                False
    Type:                  QuotaReserved
  Resource Requests:
    Name:  main
    Resources:
      Cpu:     60k
      Memory:  600Mi
      Pods:    3
Events:
  Type     Reason   Age    From             Message
  ----     ------   ----   ----             -------
  Warning  Pending  4m49s  kueue-admission  couldn't assign flavors to pod set main: insufficient quota for cpu in flavor default-flavor, request > maximum capacity (60k > 148)
```

Job will remain in Pending state indefinitely as more resources are not coming  
Trying to delete the workload directly will likely hang, as the finalizer will try to delete the job.  
Instead, list the jobs in the namespace, find the one that matches the workload and delete the job.  
On succesfully deleting the job, the workload should automatically be removed from the queue  

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get jobs -n production
NAME                              STATUS      COMPLETIONS   DURATION   AGE
job-sample-production-job-7wzqh   Suspended   0/3                      84s

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig delete workload job-sample-production-job-7wzqh-a13ae -n production
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig delete job sample-production-job-7wzqh -n production
job.batch "sample-production-job-7wzqh" deleted
```

Check the queue again, the suspended job should now be gone

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get localqueues -n production
NAME                     CLUSTERQUEUE    PENDING WORKLOADS   ADMITTED WORKLOADS
production-local-queue   cluster-queue   0                   0
```

In our cluster, we only want to allow jobs to be run via the local queues that we set up. 
Follow https://kueue.sigs.k8s.io/docs/tasks/manage/enforce_job_management/setup_job_admission_policy/ so that in our namespaces jobs can only be submitted if they have a local queue specified.

```
sample-validating-policy.yaml

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: sample-validating-admission-policy
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups:   ["batch"]
      apiVersions: ["v1"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["jobs"]
    - apiGroups:   ["jobset.x-k8s.io"]
      apiVersions: ["v1alpha2"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["jobsets"]
  matchConditions:
  - name: exclude-jobset-owned
    expression: "!(has(object.metadata.ownerReferences) && object.metadata.ownerReferences.exists(o, o.apiVersion=='jobset.x-k8s.io'&&o.kind=='JobSet'&&o.controller))"
  validations:
    - expression: "has(object.metadata.labels) && 'kueue.x-k8s.io/queue-name' in object.metadata.labels && object.metadata.labels['kueue.x-k8s.io/queue-name'] != ''"
      message: "The label 'kueue.x-k8s.io/queue-name' is either missing or does not have a value set."
```
```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f sample-validating-policy.yaml
validatingadmissionpolicy.admissionregistration.k8s.io/sample-validating-admission-policy created
```

```
sample-validating-policy-binding.yaml

apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: sample-validating-admission-policy-binding
spec:
  policyName: sample-validating-admission-policy
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kueue-managed: "true"
```

```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig apply -f sample-validating-policy-binding.yaml
validatingadmissionpolicybinding.admissionregistration.k8s.io/sample-validating-admission-policy-binding created

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig label namespace test 'kueue-managed=true'
namespace/test labeled

$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig label namespace production 'kueue-managed=true'
namespace/production labeled
```

try and run a job with no queue specified

```
simple-job-no-queue.yaml

apiVersion: batch/v1
kind: Job
metadata:
  generateName: sample-job-
  namespace: test
spec:
  parallelism: 3
  completions: 3
  suspend: true
  template:
    spec:
      containers:
      - name: dummy-job
        image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
        args: ["60s"]
        resources:
          requests:
            cpu: 6
            memory: "200Mi"
      restartPolicy: Never
```
```
$ kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig create -f simple-job-no-queue.yaml
The jobs "sample-job-tx8hx" is invalid: : ValidatingAdmissionPolicy 'sample-validating-admission-policy' with binding 'sample-validating-admission-policy-binding' denied request: The label 'kueue.x-k8s.io/queue-name' is either missing or does not have a value set.
```

## TODO

Figure out how to reject oversized jobs, rather than sit in PENDING (admission policy of some kind)  
How will users actually access the cluster to run jobs? auth to some service account?  
Do we need quote management, e.g. per namespace?  







