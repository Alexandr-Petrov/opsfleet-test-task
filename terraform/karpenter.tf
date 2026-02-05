# Karpenter IAM Role
resource "aws_iam_role" "karpenter" {
  name_prefix = "${var.cluster_name}-karpenter-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "karpenter" {
  name_prefix = "${var.cluster_name}-karpenter-"
  role        = aws_iam_role.karpenter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateNetworkInterface",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcs",
          "ec2:GetLaunchTemplateData",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "pricing:GetSpotPriceHistory",
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/aws/service/*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.node.arn
      }
    ]
  })
}

# Karpenter Helm Release
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.6.0"

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter.arn
        }
      }
      settings = {
        clusterName           = aws_eks_cluster.main.name
        interruptionQueue     = ""
        aws = {
          clusterEndpoint = aws_eks_cluster.main.endpoint
        }
      }
      replicas = 1
      controller = {
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
      # Ensure Karpenter runs on the managed node group
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "karpenter.sh/managed-by"
                    operator = "In"
                    values   = ["eks"]
                  },
                  {
                    key      = "node-role"
                    operator = "In"
                    values   = ["system"]
                  }
                ]
              }
            ]
          }
        }
      }
      # Tolerate the taint on system nodes
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }
      ]
    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.karpenter_system
  ]
}
