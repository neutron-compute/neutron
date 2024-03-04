
output "karpenter_node_role" {
  value = module.karpenter.iam_role_arn
}
output "NodeGroupType" {
  value = keys(local.spark_role_nodepool_nodetype_mapping)
}
