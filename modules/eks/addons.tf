# =============================================================================
# EKS Managed Addons
# =============================================================================

# --- aws-ebs-csi-driver -------------------------------------------------------
# Provisions EBS volumes for PersistentVolumeClaims. Nothing in the cluster
# needed persistent storage before observability (Phase 1: Prometheus's TSDB
# lives on an EBS gp3 volume); without this addon a PVC stays Pending forever —
# EKS ships no in-tree provisioner on current Kubernetes versions.
#
# The controller talks to the EC2 API, so it gets an IRSA role like every other
# AWS-facing workload. The service account name (ebs-csi-controller-sa in
# kube-system) is fixed by the addon.

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# AWS-managed policy purpose-built for the driver: EC2 volume/snapshot CRUD,
# scoped with conditions on the CSI-managed resource tags. Volumes encrypted
# with the account's default aws/ebs KMS key need no extra KMS statements.
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version # null = the EKS default for this cluster version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # The controller Deployment needs schedulable nodes (DEGRADED until the
  # first node group exists), and the role must already carry its permissions
  # policy — referencing the role ARN alone doesn't order the attachment, so
  # without it the controller can start unable to call EC2.
  depends_on = [
    aws_eks_node_group.system,
    aws_iam_role_policy_attachment.ebs_csi_driver,
  ]

  tags = {
    Name = "${var.cluster_name}-ebs-csi-driver"
  }
}
