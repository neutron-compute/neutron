#### this is for Tagging AWS subnets created outside of Terraform or outside this module

resource "aws_ec2_tag" "subnet_tagging" {
  for_each    = var.enable_karpenter_discovery_tag ? toset(var.subnet_ids) : []
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = module.eks.cluster_name
}

resource "aws_ec2_tag" "subnet_tagging_lb" {
  for_each    = var.enable_karpenter_discovery_tag ? toset(var.subnet_ids) : []
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "subnet_tagging_eks_cluster" {
  for_each    = var.enable_karpenter_discovery_tag ? toset(var.subnet_ids) : []
  resource_id = each.value
  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
  value       = "shared"
}
