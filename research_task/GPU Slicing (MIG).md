# Enabling GPU Slicing on Amazon EKS Clusters

## Contents Guide
- [Introduction](#introduction)

- [Recommendation](#recommendation)
- [Enabling GPU Slicing with NVIDIA Multi-Instance GPU (MIG)](#enabling-gpu-slicing-with-nvidia-multi-instance-gpu-mig-on-amazon-eks)
  - [Prerequisites](#prerequisites)
  - [Step 1: Add GPU-Enabled Node Group](#step-1-add-gpu-enabled-node-group)
  - [Step 2: Install NVIDIA GPU Operator](#step-2-install-nvidia-gpu-operator)
  - [Step 3: Verify GPU Operator Installation](#step-3-verify-gpu-operator-installation)
  - [Step 4: Configure MIG Device Partitioning](#step-4-configure-mig-device-partitioning)
  - [Step 5: Deploy Workloads Using MIG Devices](#step-5-deploy-workloads-using-mig-devices)
  - [Step 6: Clean Up Resources](#step-6-clean-up-resources)
- [Using Karpenter with NVIDIA MIG](#using-karpenter-with-nvidia-mig-on-amazon-eks)
  - [Prerequisites](#prerequisites-1)
  - [Step 1: Update Karpenter Provisioner](#step-1-update-the-karpenter-provisioner-for-gpu-nodes)
  - [Step 2: Install NVIDIA GPU Operator](#step-2-install-nvidia-gpu-operator-1)
  - [Step 3: Enable MIG Configurations](#step-3-enable-mig-configurations-with-karpenter)
  - [Step 4: Deploy Workloads with MIG Resources](#step-4-deploy-workloads-with-mig-resources)
  - [Step 5: Scale Deployments](#step-5-scale-deployments)
  - [Step 6: Validate GPU Utilization](#step-6-validate-gpu-utilization)
  - [Step 7: Cleanup](#step-7-cleanup)
- [Benefits of MIG](#mig-offers-the-following-benefits)
- [Important Considerations](#important-considerations)
- [Summary](#summary)
- [References and Additional Materials](#references-and-additional-materials)


---

## Introduction
GPU Slicing allows multiple workloads to share GPU resources efficiently. This guide explains how to enable GPU slicing on Amazon EKS clusters using NVIDIA Multi-Instance GPU (MIG) and Karpenter.

---

## Understanding GPU Slicing
GPU slicing divides a single GPU into smaller "slices," allowing multiple workloads to share resources simultaneously.

### Benefits of GPU Slicing
- **Cost Savings**: Reduces costs by maximizing GPU utilization.
- **Increased Efficiency**: Optimizes resource allocation for variable workloads.
- **Improved Latency**: Enhances performance for specific workloads.

---

## GPU Slicing Options

### 1. MIG (Multi-Instance GPU)
- **Concept**: Partitions GPUs into smaller, independent instances.
- **Use Case**: Ideal for workloads requiring consistent, isolated GPU performance.

### 2. Time Slicing
- **Concept**: Multiple workloads share the GPU by taking turns.
- **Use Case**: Suitable for tasks that can tolerate slight delays.

---

## Recommendation
The recommended approach is **MIG (Multi-Instance GPU)** due to its predictable performance and isolation. The following sections provide step-by-step instructions to enable MIG on Amazon EKS.

---

# Enabling GPU Slicing with NVIDIA Multi-Instance GPU (MIG) on Amazon EKS

## Prerequisites
- **Amazon EKS cluster** (v1.25 or later)
- **AWS CLI**
- **Helm** (v3 or later)
- **Kubectl**
- **eksctl**

---

## Step 1: Add GPU-Enabled Node Group

### Create Node Group YAML File
Save the configuration as `gpu-node-group.yaml`.

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: <your-cluster-name>
  region: <your-region>
managedNodeGroups:
  - name: gpu-workers
    instanceType: p4d.24xlarge
    minSize: 1
    desiredCapacity: 1
    maxSize: 3
    volumeSize: 200
```

### Add GPU Node Group
```bash
eksctl create nodegroup -f gpu-node-group.yaml
```

---

## Step 2: Install NVIDIA GPU Operator

### Add NVIDIA Helm Repository
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
```

### Install GPU Operator
```bash
helm upgrade gpu-operator nvidia/gpu-operator \
    --install \
    --namespace <namespace> \
    --set driver.enabled=true \
    --set devicePlugin.enabled=true \
    --set migManager.enabled=true \
    --set migManager.WITH_REBOOT=true \
    --set operator.defaultRuntime=containerd \
    --set mig.strategy=mixed \
    --set migManager.default=all-balanced
```

---

## Step 3: Verify GPU Operator Installation

```bash
kubectl get pods -n <namespace> -l app=gpu-operator
```

---

## Step 4: Configure MIG Device Partitioning
```bash
kubectl label nodes <gpu-node-name> nvidia.com/mig.config=all-balanced --overwrite
```

---

## Step 5: Deploy Workloads Using MIG Devices

Save the configuration as `mig-deployment.yaml`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mig-1g5gb-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mig-1g5gb
  template:
    metadata:
      labels:
        app: mig-1g5gb
    spec:
      containers:
      - name: workload
        image: nvidia/cuda:8.0-runtime
        resources:
          limits:
            nvidia.com/mig-1g.5gb: 1
```

Apply the deployment:
```bash
kubectl apply -f mig-deployment.yaml
```

---

## Step 6: Clean Up Resources
```bash
kubectl delete deployment mig-1g5gb-deployment
```

---

# Using Karpenter with NVIDIA MIG on Amazon EKS


## Prerequisites
- **Amazon EKS Cluster** (v1.25 or later).
- **Karpenter** is installed and configured in your cluster.
- Helm, kubectl, aws CLI, eksctl installed.
- GPU-compatible node AMIs (e.g., Bottlerocket GPU-optimized AMI or NVIDIA-enabled Amazon Linux 2).

---

## Step 1: Update the Karpenter Provisioner for GPU Nodes

You need to configure the Karpenter provisioner to specify GPU instance types, enabling nodes that support NVIDIA GPUs.

1. Create or edit your Karpenter provisioner to include GPU-capable instance types:

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: gpu-provisioner
spec:
  requirements:
    - key: "instance-type"
      operator: In
      values: ["p4d.24xlarge"]
    - key: "nvidia.com/gpu"
      operator: Exists
  provider:
    amiFamily: Bottlerocket  # Or AL2 depending on your preference
    instanceProfile: <INSTANCE_PROFILE_NAME>  # IAM role for GPU nodes
    tags:
      Name: "gpu-node"
  taints:
    - key: "nvidia.com/gpu"
      value: "true"
      effect: "NoSchedule"
  limits:
    resources:
      cpu: "5000"    # Example CPU limit
      memory: "10Ti" # Example memory limit
      nvidia.com/gpu: "32"
```

2. Apply the provisioner:

```bash
kubectl apply -f gpu-provisioner.yaml
```

---

## Step 2: Install NVIDIA GPU Operator

The NVIDIA GPU Operator enables MIG support and manages GPU resources in your cluster.

1. Add the NVIDIA Helm repository:

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
```

2. Install the GPU operator:

```bash
helm upgrade gpu-operator nvidia/gpu-operator \
  --install \
  --namespace kube-system \
  --set driver.enabled=true \
  --set mig.strategy=mixed \
  --set devicePlugin.enabled=true \
  --set migManager.enabled=true \
  --set migManager.WITH_REBOOT=true \
  --set toolkit.version=v1.13.1-centos7 \
  --set operator.defaultRuntime=containerd \
  --set gfd.version=v0.8.1 \
  --set devicePlugin.version=v0.14.0 \
  --set migManager.default=all-balanced
```

---

## Step 3: Enable MIG Configurations with Karpenter

Enable MIG on Karpenter-provisioned GPU nodes.

1. Label the provisioned GPU node for MIG configuration:

```bash
NODE_NAME=$(kubectl get nodes --selector=karpenter.sh/provisioner-name=gpu-provisioner -o jsonpath='{.items[0].metadata.name}')
kubectl label nodes $NODE_NAME nvidia.com/mig.config=all-balanced --overwrite
```

2. Verify the MIG configuration status:

```bash
kubectl describe node $NODE_NAME | grep nvidia.com/mig.config.state
```

---

## Step 4: Deploy Workloads with MIG Resources

Deploy workloads using specific MIG slices.

1. Create a deployment that requests a `1g.5gb` MIG slice:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mig1-5
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mig1-5
  template:
    metadata:
      labels:
        app: mig1-5
    spec:
      containers:
      - name: workload
        image: nvidia/cuda:11.8-base
        resources:
          limits:
            nvidia.com/mig-1g.5gb: 1
```

2. Apply the deployment:

```bash
kubectl apply -f mig-1g-5gb-deployment.yaml
```

---

## Step 5: Scale Deployments

To fully utilize the MIG-enabled GPU node, scale your deployment:

```bash
kubectl scale deployment mig1-5 --replicas=56
```

---

## Step 6: Validate GPU Utilization

1. Exec into one of the pods:

```bash
kubectl exec -it <POD_NAME> -- bash
```

2. Execute the nvidia-smi command by accessing the GPU EC2 instance via the Session Manager in the AWS Systems Manager console.

```bash
nvidia-smi
```

---

## Step 7: Cleanup

To clean up, delete the deployment and allow Karpenter to deprovision the nodes:

```bash
kubectl delete deployment mig1-5
```

---

## MIG offers the following benefits
- **Resource efficiency**: Maximizes GPU utilization by allowing multiple workloads to share a single GPU.
- **Predictable performance**: Each GPU instance operates in isolation, ensuring consistent performance for each workload.
- **Flexibility**: MIG can be configured to create GPU instances of various sizes to match workload requirements.
- **Cost-efficiency**: For businesses, it can lead to cost savings as they can get more out of their existing GPU infrastructure.
- **Enhanced security**: Each MIG partition gets it’s own dedicated memory and compute cores, ensuring different workloads do not interfere with each other thereby reducing the attack surface.

---

## Important Considerations
- **Workload Compatibility:** Not all workloads are suitable for GPU Slicing. High-memory or strict isolation workloads may need dedicated GPUs.
- **Performance Monitoring:** Monitor performance closely after enabling GPU Slicing. Optimize configuration based on usage.
- **Testing and Validation:** Thoroughly test workloads in a controlled environment before production deployment.


## Summary
This guide provides a comprehensive setup for enabling GPU slicing using NVIDIA MIG on Amazon EKS. It covers both traditional setups and configurations using Karpenter for dynamic provisioning.

  
## References and Additional Materials
- [Maximizing GPU Utilization with NVIDIA's MIG on Amazon EKS](https://aws.amazon.com/blogs/containers/maximizing-gpu-utilization-with-nvidias-multi-instance-gpu-mig-on-amazon-eks-running-more-pods-per-gpu-for-enhanced-performance/)
- [Implementing GPU Nodes with NVIDIA Drivers](https://marcincuber.medium.com/amazon-eks-implementing-and-using-gpu-nodes-with-nvidia-drivers-08d50fd637fe)
- [NVIDIA Kubernetes Documentation](https://docs.nvidia.com/datacenter/cloud-native/kubernetes/latest/index.html)
- [Maximizing GPU Utilization with NVIDIA MIG](https://medium.com/@farrukh.mustafa/maximizing-gpu-utilization-with-nvidia-mig-on-amazon-eks-c1a488641d99)
- [GPU Sharing on Amazon EKS](https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/)

