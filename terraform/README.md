# Quick Start Guide

This guide provides the essential steps to deploy the EKS cluster and test application.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl installed

## Step 1: Deploy Infrastructure

Initialize and apply the Terraform configuration:

```bash
terraform init
terraform apply
```

Review the plan and type `yes` to proceed. The deployment takes approximately 10-15 minutes and creates:
- VPC with public/private subnets
- EKS cluster (v1.34)
- Karpenter autoscaler
- Node pools for x86 and arm64 instances

## Step 2: Configure kubectl

After deployment completes, configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name opsfleet-eks
```

Verify cluster access:

```bash
kubectl get nodes
kubectl get nodepools -n karpenter
```

## Step 3: Deploy Test Application

The `test-app.yaml` includes two nginx deployments demonstrating multi-architecture support:
- **nginx-x86**: 2 replicas on x86 nodes
- **nginx-graviton**: 2 replicas on arm64/Graviton nodes

Deploy the application:

```bash
kubectl apply -f test-app.yaml
```

## Step 4: Verify Deployment

Check deployment status:

```bash
# View deployments
kubectl get deployments

# View pods and their assigned nodes
kubectl get pods -o wide

# View nodes with architecture labels
kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type
```

You should see:
- 2 `nginx-x86-*` pods running on amd64 nodes
- 2 `nginx-graviton-*` pods running on arm64 nodes
- Karpenter automatically provisioned nodes for both architectures

## Step 5: Test the Applications

Test connectivity to both services:

```bash
# Test x86 nginx
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://nginx-x86

# Test Graviton nginx
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://nginx-graviton
```

## Monitoring Karpenter

Watch Karpenter autoscaling in action:

```bash
# View Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# View node pools
kubectl get nodepools -n karpenter

# View EC2NodeClass configuration
kubectl get ec2nodeclass -n karpenter
```

## Scaling Applications

Scale deployments up or down:

```bash
# Scale up
kubectl scale deployment nginx-x86 --replicas=5
kubectl scale deployment nginx-graviton --replicas=5

# Scale down
kubectl scale deployment nginx-x86 --replicas=1
kubectl scale deployment nginx-graviton --replicas=1
```

Karpenter will automatically provision or consolidate nodes based on demand.

## Clean Up

Remove test application:

```bash
kubectl delete -f test-app.yaml
```

Destroy infrastructure:

```bash
terraform destroy
```

## Configuration Options

Customize the deployment by editing `variables.tf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-1 | AWS region |
| `cluster_name` | opsfleet-eks | EKS cluster name |
| `cluster_version` | 1.34 | Kubernetes version |
| `vpc_cidr` | 10.0.0.0/16 | VPC CIDR block |
| `environment` | poc | Environment tag |

## Troubleshooting

**Pods stuck in Pending**: Check Karpenter logs for provisioning issues
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50
```

**Nodes not provisioning**: Verify IAM roles and EC2NodeClass configuration
```bash
kubectl get ec2nodeclass -n karpenter -o yaml
```

**kubectl connection issues**: Update kubeconfig
```bash
aws eks update-kubeconfig --region us-east-1 --name opsfleet-eks
```