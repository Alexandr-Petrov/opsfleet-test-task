# Karpenter NodePools and EC2NodeClass
# These are applied via kubectl after cluster creation
# See karpenter-manifests.yaml for the actual manifests

resource "null_resource" "apply_karpenter_manifests" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
      
      # Replace variables in the manifest
      export CLUSTER_NAME=${var.cluster_name}
      export NODE_ROLE_NAME=${aws_iam_role.node.name}
      
      cat karpenter-manifests.yaml | \
        sed "s/\$${CLUSTER_NAME}/$CLUSTER_NAME/g" | \
        sed "s/\$${NODE_ROLE_NAME}/$NODE_ROLE_NAME/g" | \
        kubectl apply -f -
    EOT
  }

  depends_on = [helm_release.karpenter, aws_eks_cluster.main]

  triggers = {
    manifest_sha = filesha256("${path.module}/karpenter-manifests.yaml")
    cluster_name = var.cluster_name
  }
}

