module "iam_assumable_role_with_oidc" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "v5.33.1"
  create_role                   = true
  role_name                     = join("_", [module.eks.cluster_name, "vpc_cni"])
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-node"]
  tags                          = var.tags
}

module "ebs_csi_driver_role" {
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "v5.33.1"
  create_role                    = true
  role_name                      = join("_", [module.eks.cluster_name, "ebs_csi"])
  provider_url                   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns               = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  oidc_fully_qualified_subjects  = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  tags                           = var.tags
}
