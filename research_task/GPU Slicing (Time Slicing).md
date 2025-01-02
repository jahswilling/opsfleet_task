# Enabling GPU Sharing on Amazon EKS Using Time-Slicing

## Contents Guide

- [Introduction](#introduction)
- [Decision Matrix: MIG vs Time-Slicing](#decision-matrix-mig-vs-time-slicing)
- [Solution Overview](#solution-overview)
- [Prerequisites](#prerequisites)
- [Step-by-Step Implementation](#step-by-step-implementation)
  - [Step 1: Verify Your EKS Cluster](#step-1-verify-your-eks-cluster)
  - [Step 2: Add a GPU-Enabled Node Group](#step-2-add-a-gpu-enabled-node-group)
  - [Step 3: Deploy the NVIDIA GPU Device Plugin](#step-3-deploy-the-nvidia-gpu-device-plugin)
  - [Step 4: Enable GPU Time-Slicing](#step-4-enable-gpu-time-slicing)
  - [Step 5: Deploy Workloads](#step-5-deploy-workloads)
  - [Step 6: Validate GPU Sharing](#step-6-validate-gpu-sharing)
- [Benefits of GPU Time-Slicing](#benefits-of-gpu-time-slicing)
- [Considerations and Drawbacks](#considerations-and-drawbacks)
- [Cleanup](#cleanup)
- [Conclusion](#conclusion)

---

## Introduction

GPU sharing using time-slicing on Amazon EKS provides an efficient mechanism to optimize GPU resource utilization. This guide demonstrates how to implement GPU sharing using NVIDIA’s time-slicing feature, enabling multiple pods to share the same GPU resources effectively.

## Understanding GPU Slicing
GPU slicing divides a single GPU into smaller "slices," allowing multiple workloads to share resources simultaneously.

---

## GPU Slicing Options

### 1. MIG (Multi-Instance GPU)
- **Concept**: Partitions GPUs into smaller, independent instances.
- **Use Case**: Ideal for workloads requiring consistent, isolated GPU performance.

### 2. Time Slicing
- **Concept**: Multiple workloads share the GPU by taking turns.
- **Use Case**: Suitable for tasks that can tolerate slight delays.

---

## Decision Matrix: MIG vs Time-Slicing

| Feature                | MIG                          | Time-Slicing               |
|------------------------|-------------------------------|----------------------------|
| Isolation              | Strong                        | Weak                       |
| Flexibility            | Low (fixed partitions)        | High (dynamic allocation)  |
| Cost Efficiency        | Moderate                      | High                       |
| Use Case               | High-performance ML workloads | Cost-sensitive workloads   |

---


## Solution Overview

Amazon EKS users can enable GPU sharing by integrating the NVIDIA Kubernetes device plugin. This plugin exposes GPU resources to Kubernetes, allowing the scheduler to manage them effectively. By leveraging GPU time-slicing, multiple pods can share a single GPU, improving resource utilization and reducing costs.

---

## Prerequisites

- An existing Amazon EKS cluster (v1.25 or later)
- AWS CLI
- Helm
- Kubectl
- jq

---

## Step-by-Step Implementation

### Step 1: Verify Your EKS Cluster

Ensure your EKS cluster is running and accessible:

```bash
kubectl get nodes
```

Identify a GPU-enabled node, or prepare to add one in the next step.

### Step 2: Add a GPU-Enabled Node Group

If your cluster does not already include GPU nodes, add a GPU-optimized node group using the AWS Management Console or the following command:

```bash
aws eks create-nodegroup \
    --cluster-name <cluster-name> \
    --nodegroup-name gpu-node-group \
    --node-role <node-role-arn> \
    --subnets <subnet-ids> \
    --instance-types p3.8xlarge \
    --scaling-config minSize=1,maxSize=3,desiredSize=1
```

Replace `<cluster-name>`, `<node-role-arn>`, and `<subnet-ids>` with the appropriate values for your setup.

### Step 3: Deploy the NVIDIA GPU Device Plugin

Label the GPU node:

```bash
kubectl label node <node-name> eks-node=gpu
```

Replace `<node-name>` with the name of your GPU-enabled node.

Install the NVIDIA GPU device plugin:

```bash
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace kube-system \
  -f nvdp-values.yaml \
  --version 0.14.0
```

Ensure the plugin is running on the GPU-enabled node:

```bash
kubectl get daemonset -n kube-system | grep nvidia
```

### Step 4: Enable GPU Time-Slicing

Create a ConfigMap to enable time-slicing:

```bash
cat << EOF > nvidia-device-plugin.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-device-plugin
  namespace: kube-system
data:
  any: |-
    version: v1
    flags:
      migStrategy: none
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 10
EOF
kubectl apply -f nvidia-device-plugin.yaml
```

Update the NVIDIA device plugin to apply the time-slicing configuration:

```bash
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace kube-system \
  -f nvdp-values.yaml \
  --version 0.14.0 \
  --set config.name=nvidia-device-plugin \
  --force
```

Validate the GPU capacity after enabling time-slicing:

```bash
kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | {name: .metadata.name, capacity: .status.capacity}'
```

### Step 5: Deploy Workloads

Deploy a CUDA application for GPU utilization test:

```bash
cat << EOF > cuda-gpu-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-timeslice-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpu-timeslice-test
  template:
    metadata:
      labels:
        app: gpu-timeslice-test
    spec:
      containers:
      - name: workload
        image: nvidia/cuda:11.8-base
        command: ["nvidia-smi"]
        resources:
          limits:
            nvidia.com/gpu: 1

EOF
kubectl apply -f cuda-gpu-deployment.yaml
```

### Step 6: Validate GPU Sharing

Execute the nvidia-smi command by accessing the GPU EC2 instance via the Session Manager in the AWS Systems Manager console.

```bash
nvidia-smi
```

---

## Karpenter Integration

### Step 1: Install and Configure Karpenter

Install Karpenter following its [official guide](https://karpenter.sh/docs/getting-started/). Ensure IAM roles and permissions are properly set.

### Step 2: Configure GPU Node Provisioners

Define a Karpenter provisioner for GPU instances:

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: gpu-provisioner
spec:
  requirements:
    - key: "instance-type"
      operator: In
      values:
        - "p3.2xlarge"
        - "p4d.24xlarge"
        - "g4dn.xlarge"
    - key: "kubernetes.io/arch"
      operator: In
      values:
        - "amd64"
  limits:
    resources:
      cpu: "1000"
      memory: "1000Gi"
  provider:
    instanceProfile: <instance-profile>
    subnetSelector:
      karpenter.sh/discovery: <cluster-name>
    securityGroupSelector:
      karpenter.sh/discovery: <cluster-name>
```

Apply the provisioner:

```bash
kubectl apply -f karpenter-gpu-provisioner.yaml
```

### Step 3: Deploy NVIDIA Plugin with Karpenter

Deploy the NVIDIA Device Plugin as described earlier. Ensure Karpenter provisions nodes dynamically for GPU workloads.

### Step 4: Validate and Test Workloads

Deploy workloads using GPU resources, and Karpenter will automatically scale nodes to match demands.

---

## Benefits of GPU Time-Slicing

- **Improved Resource Utilization**: Enables multiple workloads to share the same GPU, maximizing utilization.
- **Cost Optimization**: Reduces costs by spreading GPU usage across more workloads.
- **Increased Throughput**: Supports more workloads simultaneously, enhancing system performance.
- **Flexibility**: Accommodates a variety of workloads, including machine learning and graphics rendering.
- **Compatibility**: Time-slicing can be beneficial for older generation GPUs that don’t support other sharing mechanisms like MIG.

---

## Considerations and Drawbacks

- **No Memory Isolation**: Tasks share the same GPU memory, increasing the risk of interference.
- **Potential Latency**: Time-slicing introduces slight delays as tasks take turns using the GPU.
- **Resource Management Complexity**: Managing fair GPU allocation across tasks can be challenging.
- **Potential for starvation**: Without proper management, some tasks might get more GPU time than others, leading to resource starvation for less prioritized tasks.

---

## Cost Projections and Savings

**Example: Running 10 tasks using 1 GPU each:**

- **Dedicated GPUs (On-Demand):** $12.24/hr (p3.8xlarge) * 10 = $122.40/hr
- **GPU Slicing (On-Demand):** $12.24/hr (p3.8xlarge) shared among 10 tasks = $12.24/hr

**Savings (On-Demand):** $122.40/hr - $12.24/hr = **$110.16/hr**

**Example with Spot Pricing:**

- **Dedicated GPUs (Spot):** $1.7031/hr (p3.8xlarge) * 10 = $17.03/hr
- **GPU Slicing (Spot):** $1.7031/hr (p3.8xlarge) shared among 10 tasks = $1.7031/hr

**Savings (Spot):** $17.03/hr - $1.7031/hr = **$15.33/hr**

**Reserved Instances (1-Year):**

- **Dedicated GPUs:** $12.61/hr (p3.8xlarge) * 10 = $126.10/hr
- **GPU Slicing:** $12.61/hr (p3.8xlarge) shared among 10 tasks = $12.61/hr

**Savings (Reserved - 1 Year):** $126.10/hr - $12.61/hr = **$113.49/hr**

**Analysis:**
GPU slicing provides substantial cost savings compared to dedicated GPU provisioning across all pricing models. This makes it particularly attractive for variable or bursty workloads, where maximizing GPU utilization is critical.

**Disclaimer:**
This analysis is a simplified illustration and may not accurately reflect the actual cost savings in all scenarios. The actual cost savings will depend on various factors, including workload characteristics, resource utilization, and specific pricing models.

---

## Cleanup

To avoid incurring charges, delete the time-slicing configuration and workloads when they are no longer needed:

```bash
kubectl delete deployment gpu-timeslice-test
kubectl delete configmap nvidia-device-plugin -n kube-system
```

---

## Conclusion

Using GPU sharing on Amazon EKS with NVIDIA’s time-slicing optimizes GPU utilization, reduces costs, and supports diverse workloads. By integrating this with Karpenter, you achieve an even more optimized, scalable, and cost-efficient solution for GPU workloads, making it ideal for machine learning and other compute-intensive tasks. While there are challenges to consider, the combined benefits of GPU sharing and Karpenter's automation make it a valuable strategy for modern Kubernetes environments.

---

## References and Additional Resources
- [GPU Sharing on Amazon EKS](https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/)

- [Implementing GPU Nodes with NVIDIA Drivers](https://marcincuber.medium.com/amazon-eks-implementing-and-using-gpu-nodes-with-nvidia-drivers-08d50fd637fe)
- [NVIDIA Kubernetes Documentation](https://docs.nvidia.com/datacenter/cloud-native/kubernetes/latest/index.html)
- [Time Slicing GPUs with Karpenter](https://dev.to/aws/time-slicing-gpus-with-karpenter-43nn)
- [Maximizing GPU Utilization with NVIDIA MIG](https://medium.com/@farrukh.mustafa/maximizing-gpu-utilization-with-nvidia-mig-on-amazon-eks-c1a488641d99)
