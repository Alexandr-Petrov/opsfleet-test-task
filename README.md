# OpsFleet Test Task

This repository contains solutions for OpsFleet's technical and architectural tasks.

## Structure

### 📁 [/terraform](./terraform)
Contains Terraform code to deploy the **technical task** - an EKS cluster with Karpenter autoscaler supporting both x86 and arm64 (Graviton) instances.

**Quick Start:**
```bash
cd terraform
terraform init
terraform apply
```

See the [terraform directory](./terraform) for detailed deployment instructions.

### 📁 [/architecture](./architecture)
Contains documentation for the **architectural task** - a comprehensive 3-tier web application architecture design with high availability, security, and scalability considerations.

See the [architecture directory](./architecture) for the complete architectural design and documentation.

## Quick Links

- [Terraform Implementation Guide](./terraform/README.md)
- [Architectural Design Document](./architecture/README.md)

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured
- kubectl installed (for Kubernetes deployment)