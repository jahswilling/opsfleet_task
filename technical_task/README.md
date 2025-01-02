# Terraform EKS Cluster with Karpenter

This repository provisions an Amazon EKS cluster with Terraform, utilizing [Karpenter](https://karpenter.sh) for efficient cluster autoscaling. It is designed to deploy workloads on both x86 and Graviton (arm64) instances, enabling flexibility and cost optimization.

## Prerequisites

1. **Tools**:
   - [Terraform](https://www.terraform.io/)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - AWS CLI, configured with proper credentials.
2. **AWS IAM Permissions**: Ensure your AWS credentials have permissions to provision the necessary resources (e.g., EKS, VPC, IAM).

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/jahswilling/opsfleet_task.git
   cd opsfleet_task/technical_task/statefiles
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review and customize the variables in the `variables.tf` file or pass them via a `terraform.tfvars` file.

4. Plan the infrastructure:
   ```bash
   terraform plan
   ```

5. Deploy the state bucket and dynamo table for the project:
   ```bash
   terraform apply
   ```

6. Since the bucket and the dynamo table has been created go to the project folder (`terraform` folder on the home of the repo):
   ```bash
   cd ../opsfleet_task/technical_task/terraform
   ```

7. Repeat the commands in step `2,3,4,5`for the project which will use the initially created bucket and dynamodb table:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

6. Configure `kubectl` to access the cluster:
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```

## Deploying Workloads on x86 or Graviton Instances

By default, Karpenter provisions nodes based on workload requirements. To target specific architectures (x86 or arm64), you can specify node affinity or tolerations in your pod or deployment manifests. (Examples are in the example_manifest `/opsfleet_task/technical_task/example_manifest` )

### Example 1: Deploying on x86 Instances

Create a deployment that runs only on x86 nodes by specifying the `kubernetes.io/arch: amd64` node affinity.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: x86-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: x86-app
  template:
    metadata:
      labels:
        app: x86-app
    spec:
      containers:
        - name: x86-app
          image: nginx:latest
          resources:
            requests:
              cpu: 500m
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
```
Apply the manifest:
```bash
kubectl apply -f x86-deployment.yaml
```

### Example 2: Deploying on Graviton Instances (arm64)

Create a deployment that runs only on Graviton nodes by specifying the `kubernetes.io/arch: arm64` node affinity.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: arm64-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: arm64-app
  template:
    metadata:
      labels:
        app: arm64-app
    spec:
      containers:
        - name: arm64-app
          image: public.ecr.aws/nginx/nginx:arm64v8
          resources:
            requests:
              cpu: 500m
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/arch
                    operator: In
                    values:
                      - arm64
```
Apply the manifest:
```bash
kubectl apply -f arm64-deployment.yaml
```

## Notes

- Karpenter dynamically provisions nodes based on pod requirements, ensuring optimal resource usage.
- Spot instances are prioritized for cost-effectiveness. To disable Spot instances, modify the `karpenter.sh/capacity-type` label in the `NodePool` configuration.

