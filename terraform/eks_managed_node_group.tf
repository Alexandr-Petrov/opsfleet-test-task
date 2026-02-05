# EKS Managed Node Group for Karpenter and system components
# This ensures Karpenter runs on stable, non-autoscaled infrastructure

resource "aws_eks_node_group" "karpenter_system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-karpenter-system"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = var.cluster_version

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Use t3.medium for system components (lab environment)
  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  # Labels to identify these nodes
  labels = {
    "node-group"              = "karpenter-system"
    "karpenter.sh/managed-by" = "eks"
    "node-role"               = "system"
  }

  # Taint to prevent regular workloads from scheduling here
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name        = "${var.cluster_name}-karpenter-system-ng"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "karpenter-controller"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_base,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_registry,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
