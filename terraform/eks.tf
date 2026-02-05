resource "aws_eks_cluster" "main" {
  name            = var.cluster_name
  version         = var.cluster_version
  role_arn        = aws_iam_role.cluster.arn
  
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.cluster]

  tags = {
    Name = var.cluster_name
  }
}

# OIDC Provider (needed for Karpenter and other add-ons)
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

# Tag the EKS-managed cluster security group for Karpenter discovery
resource "aws_ec2_tag" "cluster_sg_karpenter_discovery" {
  resource_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery/${var.cluster_name}"
  value       = var.cluster_name
}
