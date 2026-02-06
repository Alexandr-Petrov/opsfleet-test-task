# Innovate Inc. Cloud Infrastructure Architecture

## Executive Summary

This document presents an AWS cloud infrastructure architecture for Innovate Inc.'s web application a REST API backend (Python/Flask) with a React SPA frontend, backed by PostgreSQL. The design prioritizes security, scalability (from hundreds to millions of users), cost-efficiency for a startup budget, and operational simplicity using managed services and Kubernetes.

---

## 1. High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Organization                                       │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  Management   │    │  Production  │    │   Staging    │    │   Shared     │       │
│  │   Account     │    │   Account    │    │   Account    │    │  Services    │       │
│  └──────────────┘    └──────┬───────┘    └──────────────┘    └──────────────┘       │
└─────────────────────────────┼───────────────────────────────────────────────────────┘
                              │
           ┌──────────────────▼──────────────────┐
           │         Production Account          │
           │                                      │
           │  ┌──────────────────────────────┐   │
           │  │        CloudFront CDN        │   │
           │  │   (React SPA + API caching)  │   │
           │  └──────────┬───────────────────┘   │
           │             │                        │
           │  ┌──────────▼───────────────────┐   │
           │  │      S3 Bucket (SPA Assets)  │   │
           │  └──────────────────────────────┘   │
           │                                      │
           │  ┌──────────────────────────────────────────────────────────┐  │
           │  │                    VPC (10.0.0.0/16)                     │  │
           │  │                                                          │  │
           │  │  ┌─────────────────────┐  ┌─────────────────────┐       │  │
           │  │  │  Public Subnet AZ-a │  │  Public Subnet AZ-b │       │  │
           │  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │       │  │
           │  │  │  │  NAT Gateway  │  │  │  │  NAT Gateway  │  │       │  │
           │  │  │  └───────────────┘  │  │  └───────────────┘  │       │  │
           │  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │       │  │
           │  │  │  │  ALB (public) │  │  │  │  ALB (public) │  │       │  │
           │  │  │  └───────────────┘  │  │  └───────────────┘  │       │  │
           │  │  └─────────────────────┘  └─────────────────────┘       │  │
           │  │                                                          │  │
           │  │  ┌─────────────────────┐  ┌─────────────────────┐       │  │
           │  │  │ Private Subnet AZ-a │  │ Private Subnet AZ-b │       │  │
           │  │  │                     │  │                     │       │  │
           │  │  │  ┌──────────────────┴──┴──────────────────┐  │       │  │
           │  │  │  │         Amazon EKS Cluster             │  │       │  │
           │  │  │  │                                        │  │       │  │
           │  │  │  │  ┌──────────┐  ┌──────────┐           │  │       │  │
           │  │  │  │  │ Flask API│  │ Flask API│  (pods)   │  │       │  │
           │  │  │  │  └──────────┘  └──────────┘           │  │       │  │
           │  │  │  │  ┌───────────────────────────┐        │  │       │  │
           │  │  │  │  │  Karpenter (autoscaler)   │        │  │       │  │
           │  │  │  │  └───────────────────────────┘        │  │       │  │
           │  │  │  └────────────────────────────────────┘  │  │       │  │
           │  │  └─────────────────────┘  └─────────────────────┘       │  │
           │  │                                                          │  │
           │  │  ┌─────────────────────┐  ┌─────────────────────┐       │  │
           │  │  │   Data Subnet AZ-a  │  │   Data Subnet AZ-b  │       │  │
           │  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │       │  │
           │  │  │  │  RDS Primary  │  │  │  │  RDS Standby  │  │       │  │
           │  │  │  │  (PostgreSQL) │  │  │  │  (PostgreSQL) │  │       │  │
           │  │  │  └───────────────┘  │  │  └───────────────┘  │       │  │
           │  │  │  ┌───────────────┐  │  │                     │       │  │
           │  │  │  │  ElastiCache  │  │  │                     │       │  │
           │  │  │  │  (Redis)      │  │  │                     │       │  │
           │  │  │  └───────────────┘  │  │                     │       │  │
           │  │  └─────────────────────┘  └─────────────────────┘       │  │
           │  └──────────────────────────────────────────────────────────┘  │
           └──────────────────────────────────────────────────────────────────┘
```

### CI/CD & Supporting Services

```
┌────────────────────────────────────────────────────────────────┐
│                    Shared Services Account                      │
│                                                                │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│  │   GitHub      │──▶│  GitHub      │──▶│    Amazon    │       │
│  │   Repository  │   │  Actions     │   │    ECR       │       │
│  └──────────────┘   └──────┬───────┘   └──────┬───────┘       │
│                            │                   │               │
│                            ▼                   ▼               │
│                    ┌───────────────────────────────┐           │
│                    │  ArgoCD (GitOps Deployment)   │           │
│                    │  → syncs to EKS clusters      │           │
│                    └───────────────────────────────┘           │
│                                                                │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│  │  Terraform   │   │  AWS Secrets │   │  Centralized │       │
│  │  State (S3)  │   │  Manager     │   │  Logging     │       │
│  └──────────────┘   └──────────────┘   └──────────────┘       │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. Cloud Environment Structure

### 2.1 AWS Account Strategy

We recommend an **AWS Organization** with 4 accounts:

| Account | Purpose | Justification |
|---------|---------|---------------|
| **Management** | Organization root, billing consolidation, IAM Identity Center (SSO), SCPs | Single pane of glass for billing; enforces org-wide guardrails |
| **Shared Services** | CI/CD pipelines, ECR registry, Terraform state, centralized logging, DNS (Route 53) | Shared tooling isolated from workloads; avoids duplication across environments |
| **Staging** | Pre-production environment mirroring prod | Safe testing ground; blast radius isolated from production |
| **Production** | Live workloads, customer-facing infrastructure | Full isolation of production data and traffic |

**Why this structure:**

- **Blast radius isolation** — a misconfiguration in staging cannot affect production resources, IAM roles, or networking.
- **Billing clarity** — per-account cost allocation without complex tagging strategies; each team/environment has clear cost attribution.
- **Least-privilege access** — developers get broad permissions in staging but restricted access in production via IAM Identity Center permission sets.
- **Service Control Policies (SCPs)** — enforce guardrails at the org level (e.g., deny regions outside `us-east-1`/`eu-west-1`, require encryption, prevent public S3 buckets).

**For a startup on day one**, if 4 accounts feels heavy, start with **3 accounts** (Management, Shared Services, Production) and introduce Staging when the team grows beyond 3-5 engineers. The Management and Shared Services accounts have minimal running costs.

---

## 3. Network Design

### 3.1 VPC Architecture

Each workload account (Staging, Production) gets its own VPC. The production VPC design:

| Component | CIDR / Details |
|-----------|----------------|
| **VPC** | `10.0.0.0/16` (65,536 IPs — room to grow) |
| **Public Subnets** | `10.0.0.0/20`, `10.0.16.0/20` (2 AZs, ~4k IPs each) |
| **Private Subnets (Compute)** | `10.0.128.0/18`, `10.0.192.0/18` (2 AZs, ~16k IPs each) |
| **Private Subnets (Data)** | `10.0.64.0/20`, `10.0.80.0/20` (2 AZs, ~4k IPs each) |

**Key design decisions:**

- **3-tier subnet layout** — public (load balancers, NAT gateways), private-compute (EKS nodes), private-data (RDS, ElastiCache). This enables fine-grained Network ACLs between tiers.
- **2 Availability Zones minimum** — balances HA against cost. Scale to 3 AZs when traffic justifies it.
- **Large private compute subnets (`/18`)** — Kubernetes assigns one IP per pod (with AWS VPC CNI), so pods consume IPs rapidly. 16k IPs per AZ prevents IP exhaustion at scale.
- **NAT Gateways per AZ** — ensures AZ-independent internet egress; avoids cross-AZ single point of failure.

### 3.2 Network Security

```
Internet
    │
    ▼
┌─────────────────────┐
│  AWS WAF + Shield   │  ← DDoS protection, OWASP rules
│  (on CloudFront)    │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  CloudFront CDN     │  ← TLS termination, geo-restriction
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  ALB (public subnet)│  ← TLS, path-based routing
│  SG: 443 from CF    │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  EKS Pods (private) │  ← No public IPs
│  SG: from ALB only  │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  RDS (data subnet)  │  ← No internet access
│  SG: 5432 from EKS  │
└─────────────────────┘
```

**Security layers:**

1. **AWS WAF** on CloudFront — managed rule groups for OWASP Top 10, rate limiting, IP reputation filtering. Blocks malicious requests before they reach the application.
2. **AWS Shield Standard** (free) for DDoS mitigation; upgrade to Shield Advanced when revenue justifies the $3k/month.
3. **Security Groups** — stateful, least-privilege:
   - ALB SG: inbound 443 from CloudFront managed prefix list only
   - EKS node SG: inbound from ALB SG only (app port)
   - RDS SG: inbound 5432 from EKS node SG only
4. **Network ACLs** — stateless second boundary between subnet tiers (e.g., data subnets deny all traffic except from compute subnets on port 5432).
5. **VPC Flow Logs** — enabled on all subnets, shipped to CloudWatch Logs for audit and anomaly detection.
6. **No public endpoints** — EKS nodes and databases have no public IPs. All egress goes through NAT Gateways. EKS API endpoint is private + public (restricted by CIDR allowlist for `kubectl` access).
7. **Encryption in transit** — TLS everywhere: CloudFront → ALB (ACM certificate), ALB → pods (optional mTLS via service mesh), pods → RDS (enforced via `rds.force_ssl`).
8. **Encryption at rest** — AWS KMS (customer-managed keys) for EBS, RDS, S3, and ECR.

---

## 4. Compute Platform — Amazon EKS

### 4.1 Why EKS

- **Managed control plane** — AWS handles etcd, API server patching, and HA. Innovate Inc. doesn't need a Kubernetes team on day one.
- **Deep AWS integration** — IAM Roles for Service Accounts (IRSA), VPC CNI (native pod networking), ALB Ingress Controller, CloudWatch Container Insights.
- **Ecosystem maturity** — largest managed Kubernetes share; best tooling and community support.

### 4.2 Cluster Architecture

| Component | Configuration |
|-----------|---------------|
| **EKS Version** | Latest stable (currently 1.31) |
| **Control Plane** | Managed by AWS, multi-AZ |
| **System Node Group** | EKS Managed, `t3.medium`, 2 nodes, ON_DEMAND — runs karpenter, CoreDNS, kube-proxy |
| **Workload Nodes** | Karpenter-provisioned, Graviton (`t4g.*` / `m7g.*`) + x86 (`t3.*` / `m7i.*`), Spot + On-Demand |

### 4.3 Node Groups & Autoscaling (Karpenter)

**Why Karpenter over Cluster Autoscaler:**
- Provisions right-sized nodes per pod requirements (no pre-defined ASG instance types)
- 60-90 second node launch latency vs. 3-5 minutes with CA
- Native Spot instance diversification and handling
- Cost-aware consolidation — automatically replaces underutilized nodes

**Node Pool Strategy:**

| Pool | Architecture | Instance Types | Capacity Type | Purpose |
|------|-------------|----------------|---------------|---------|
| `system` | amd64 | t3.medium | On-Demand | Karpenter, CoreDNS, monitoring agents |
| `general` | arm64 (Graviton) | t4g.medium → m7g.2xlarge | Spot (preferred), On-Demand fallback | Flask API workloads (default) |
| `general-x86` | amd64 | t3.medium → m7i.2xlarge | Spot (preferred), On-Demand fallback | x86-only workloads if needed |

**Graviton-first strategy:** Graviton instances offer ~20% better price/performance vs. x86. Flask/Python workloads are fully compatible. Default workloads to Graviton; only use x86 when a dependency requires it.

**Resource allocation:**
- Pod resource requests/limits are mandatory (enforced via OPA/Gatekeeper admission policy)
- Karpenter `limits` per pool cap total cluster size to prevent runaway costs
- Vertical Pod Autoscaler (VPA) in recommendation mode to right-size resource requests over time

### 4.4 Scaling Strategy

```
Users → CloudFront → ALB → EKS (HPA scales pods) → Karpenter (scales nodes)
```

- **Horizontal Pod Autoscaler (HPA)** — scales Flask API pods based on CPU utilization (target: 70%) and custom metrics (requests per second via Prometheus).
- **Karpenter** — reacts to pending pods within seconds, provisions appropriately-sized nodes.
- **Scale-to-zero non-prod** — staging cluster Karpenter pools consolidate aggressively; non-business-hours scaling reduces cost.

### 4.5 Containerization Strategy

**Image Building:**

```
Developer pushes code
        │
        ▼
GitHub Actions CI Pipeline
        │
        ├── Lint + Unit Tests
        ├── Build multi-arch image (docker buildx)
        │   ├── linux/amd64
        │   └── linux/arm64
        ├── Trivy vulnerability scan
        ├── Push to Amazon ECR
        └── Update Kubernetes manifests (GitOps)
```

- **Multi-architecture images** — `docker buildx` builds for both `amd64` and `arm64` in CI. A single image tag works on both Graviton and x86 nodes. This is essential for the Graviton-first strategy.
- **Amazon ECR** — private registry in Shared Services account, cross-account pull via resource policy. Image scanning enabled. Lifecycle policies auto-expire untagged images after 14 days.
- **Base images** — pinned, minimal base images (`python:3.12-slim`). Rebuilt weekly to pick up security patches.
- **Image tagging** — `<branch>-<short-sha>` for traceability. Production uses immutable tags, never `latest`.

**Deployment (GitOps with ArgoCD):**

- Application manifests live in a separate Git repo (or `deploy/` directory).
- ArgoCD watches the repo and syncs desired state to the cluster.
- Promotion flow: merge to `main` → auto-deploy to staging → manual approval → ArgoCD syncs to production.
- Rollback: `git revert` or ArgoCD one-click rollback to previous sync.

**Kubernetes Resources per service:**

```yaml
# Example: Flask API Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: innovate-api
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      # Prefer Graviton nodes
      nodeSelector:
        kubernetes.io/arch: arm64
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
      containers:
        - name: api
          image: <account>.dkr.ecr.us-east-1.amazonaws.com/innovate-api:main-abc1234
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 15
```

---

## 5. Database — Amazon RDS for PostgreSQL

### 5.1 Why RDS (not Aurora, not self-managed)

| Option | Verdict | Reasoning |
|--------|---------|-----------|
| **Self-managed on EC2/EKS** | ❌ | Operational burden too high for a small team |
| **Aurora PostgreSQL** | ⏳ Future | Better at scale but ~2x cost of RDS; overkill for initial few hundred users |
| **RDS for PostgreSQL** | ✅ Now | Managed, cost-effective, easy migration path to Aurora later |

**Start with RDS**, migrate to Aurora when read-heavy workload or cross-region replication is needed. The migration is straightforward (snapshot → restore to Aurora).

### 5.2 Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Engine** | PostgreSQL 16 | Latest stable |
| **Instance (initial)** | `db.t4g.medium` (Graviton, 2 vCPU, 4 GB) | Cost-effective for low initial load (~$50/month) |
| **Storage** | gp3, 100 GB, auto-scaling up to 500 GB | gp3 gives consistent IOPS at lower cost than gp2 |
| **Multi-AZ** | Yes | Automatic failover for HA; synchronous standby replica |
| **Encryption** | Enabled (KMS CMK) | Required for sensitive user data |
| **SSL** | Enforced (`rds.force_ssl = 1`) | Encryption in transit |
| **Parameter Group** | Custom — tuned `shared_buffers`, `work_mem` | Optimize for workload |

### 5.3 Backup & Recovery

| Mechanism | Configuration | RPO | RTO |
|-----------|---------------|-----|-----|
| **Automated Backups** | Retention: 14 days, backup window: 03:00-04:00 UTC | Up to 5 minutes (point-in-time) | ~15 minutes |
| **Manual Snapshots** | Before deployments, before migrations | Zero (point-in-time) | ~15 minutes |
| **Cross-Region Snapshot Copy** | Daily async copy to `eu-west-1` | 24 hours | 1-2 hours (restore in new region) |

### 5.4 High Availability

- **Multi-AZ deployment** — RDS maintains a synchronous standby in a second AZ. Automatic failover (typically 60-120 seconds) on primary failure, AZ outage, or instance failure.
- **Connection management** — Application connects via RDS endpoint DNS (auto-resolves to current primary). Use PgBouncer as a sidecar or separate pod for connection pooling (Flask's per-request model can exhaust connections at scale).

### 5.5 Disaster Recovery

| Scenario | Strategy | Recovery |
|----------|----------|----------|
| **AZ failure** | Multi-AZ automatic failover | Automatic, 60-120s |
| **Region failure** | Cross-region snapshot restore | Manual, 1-2 hours |
| **Data corruption / accidental deletion** | Point-in-time recovery (PITR) | Manual, ~15 minutes |
| **Complete account compromise** | Cross-account snapshot copy (to Management account) | Manual, 1-2 hours |

### 5.6 Scaling Path

1. **Day 1:** `db.t4g.medium`, single-writer Multi-AZ
2. **Growing:** Vertical scaling to `db.r7g.large` / `db.r7g.xlarge` (zero-downtime resize)
3. **Read-heavy:** Add RDS Read Replicas (or migrate to Aurora with up to 15 read replicas)
4. **Global:** Aurora Global Database for cross-region active reads

---

## 6. Frontend — Static SPA Hosting

The React SPA is **not** served from the EKS cluster:

| Component | Purpose |
|-----------|---------|
| **S3 Bucket** | Hosts built React static assets (HTML, JS, CSS) |
| **CloudFront** | CDN for global low-latency delivery, TLS termination, caching |
| **Route 53** | DNS with health-checked alias records to CloudFront |

**Benefits:** Zero compute cost for frontend serving, global edge caching, trivial scaling to millions of users.

**API routing:** CloudFront uses behavior-based routing — `/api/*` requests are forwarded to the ALB (EKS), everything else serves from S3.

---

## 7. Observability

| Pillar | Tool | Purpose |
|--------|------|---------|
| **Metrics** | Prometheus + Grafana (or CloudWatch Container Insights) | Cluster, node, pod, and application metrics |
| **Logging** | Fluent Bit → CloudWatch Logs (or OpenSearch) | Centralized structured logging from all pods |
| **Tracing** | AWS X-Ray or OpenTelemetry | Request tracing across API endpoints |
| **Alerting** | Grafana Alerts or CloudWatch Alarms → SNS → PagerDuty/Slack | On-call notification for SLO breaches |

**Start simple:** CloudWatch Container Insights + Fluent Bit on day one. Migrate to Prometheus/Grafana stack when the team has capacity to operate it.

---

## 8. Security Summary

| Area | Measure |
|------|---------|
| **Identity** | IAM Identity Center (SSO), MFA enforced, no long-lived keys |
| **Secrets** | AWS Secrets Manager, injected into pods via External Secrets Operator |
| **Container Security** | Trivy scanning in CI, ECR image scanning, read-only root filesystem |
| **Network** | Private subnets, SGs, NACLs, no public endpoints for data/compute |
| **Data at Rest** | KMS encryption on EBS, RDS, S3, ECR |
| **Data in Transit** | TLS everywhere (ACM certificates) |
| **Compliance** | AWS Config rules, GuardDuty enabled, CloudTrail in all accounts |
| **K8s Security** | Pod Security Standards (restricted), RBAC, network policies (Calico/Cilium) |
| **Supply Chain** | Pinned base images, dependency scanning (Dependabot/Snyk), signed images |

---

## 9. Cost Optimization

| Strategy | Impact |
|----------|--------|
| **Graviton instances** | ~20% savings vs. equivalent x86 |
| **Spot instances** (non-critical workloads) | Up to 70-90% savings |
| **Karpenter consolidation** | Eliminates idle node capacity |
| **RDS Reserved Instances** (after 3 months of stable usage) | 30-40% savings |
| **S3 + CloudFront for SPA** | Near-zero frontend hosting cost |
| **Right-sizing** | VPA recommendations → adjust requests quarterly |
| **Staging scale-down** | Reduce/stop staging outside business hours |

**Estimated initial monthly cost (low traffic):**

| Service | Estimate |
|---------|----------|
| EKS control plane | $73 |
| System node group (1x t3.medium On-Demand) | ~$30 |
| Workload nodes (2-3x t4g.small Spot) | ~$15-25 |
| RDS PostgreSQL (db.t4g.medium Multi-AZ) | ~$100 |
| NAT Gateway (2x) | ~$65 |
| CloudFront + S3 | ~$5 |
| ECR, Secrets Manager, misc | ~$10 |
| **Total** | **~$300-310/month** |

---

## 10. Migration & Growth Path

### Phase 1 — Launch (Month 1-3)
- Deploy with this architecture
- Single EKS cluster, 2 AZs
- RDS `db.t4g.medium`
- Manual deployments → ArgoCD setup

### Phase 2 — Growth (Month 3-12)
- Enable HPA + Karpenter tuning based on real traffic patterns
- Add RDS read replica if read-heavy
- Implement Prometheus/Grafana observability stack
- Purchase RDS Reserved Instances
- Add WAF rate limiting rules based on observed patterns

### Phase 3 — Scale (Year 2+)
- Migrate to Aurora PostgreSQL for auto-scaling reads
- Consider Aurora Global Database if going multi-region
- Add ElastiCache (Redis) for session/query caching
- Evaluate service mesh (Istio/Linkerd) for mTLS between microservices
- 3 AZ deployment for higher availability
- Consider multi-region active-passive setup

---

## Appendix A: Key AWS Services Used

| Service | Role in Architecture |
|---------|---------------------|
| AWS Organizations | Multi-account management |
| IAM Identity Center | SSO and access management |
| VPC | Network isolation |
| EKS | Managed Kubernetes |
| Karpenter | Node autoscaling |
| ECR | Container image registry |
| RDS PostgreSQL | Managed database |
| S3 | SPA hosting, backups, Terraform state |
| CloudFront | CDN and edge caching |
| Route 53 | DNS management |
| ACM | TLS certificates |
| WAF | Web application firewall |
| KMS | Encryption key management |
| Secrets Manager | Secrets storage |
| CloudWatch | Monitoring and logging |
| GuardDuty | Threat detection |
| CloudTrail | API audit logging |
