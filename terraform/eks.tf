# EKS Cluster
resource "aws_eks_cluster" "conbench" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_cidr_blocks
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# EKS Node Group
resource "aws_eks_node_group" "conbench" {
  cluster_name    = aws_eks_cluster.conbench.name
  node_group_name = "${local.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size

  # Update strategy
  update_config {
    max_unavailable = 1
  }

  # Labels for Kubernetes
  labels = {
    role = "conbench-app"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-node-group"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  # Ignore changes to desired_size (allow autoscaling)
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# OIDC Provider for EKS (needed for IAM roles for service accounts)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.conbench.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.conbench.identity[0].oidc[0].issuer

  tags = local.common_tags
}

# ConfigMap for aws-auth (allows nodes to join cluster)
# This is handled automatically by EKS for managed node groups,
# but included here for reference if you need custom RBAC
