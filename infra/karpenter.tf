locals {
  spark_role_nodepool_mapping = merge([
    for teams_key in keys(var.spark_roles) : {
      for nodepools in keys(var.spark_roles[teams_key]) :
      "${teams_key}-${nodepools}" => var.spark_roles[teams_key][nodepools]
    }
  ]...)

  spark_role_nodepool_nodetype_mapping = merge([
    for teams_key in keys(local.spark_role_nodepool_mapping) : {
      for nodetype in keys(local.spark_role_nodepool_mapping[teams_key]) :
      "${teams_key}-${nodetype}" => local.spark_role_nodepool_mapping[teams_key][nodetype]
    }
  ]...)

  karpenter_version = "v0.34.0"
  ### This is required to monitor and create datadog metrics for karpenter integration
  ### the formatting is absolutely important here as we are pushing a mutiline string as 
  ### yaml to the helm value file
  datadog_sidecar             = <<-EOT

    - image: public.ecr.aws/datadog/agent:7.50.3
      name: datadog-agent
      env:
        - name: DD_API_KEY
          value: ${var.datadog_api_key}
        - name: DD_SITE
          value: "datadoghq.com"
        - name: DD_EKS_FARGATE
          value: "true"
        - name: DD_CLUSTER_NAME
          value: ${module.eks.cluster_name}
        - name: DD_TAGS
          value: 'env:${var.env} cluster_name:${module.eks.cluster_name}'
        - name: DD_CONTAINER_EXCLUDE 
          value: "name:^datadog-agent$"
        - name: DD_KUBERNETES_KUBELET_NODENAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: spec.nodeName
  EOT
  datadog_sidecar_deifinition = var.enable_datadog == true ? local.datadog_sidecar : tostring("[]")
}


################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source                        = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                       = "20.2.1"
  cluster_name                  = module.eks.cluster_name
  enable_irsa                   = true
  irsa_oidc_provider_arn        = module.eks.oidc_provider_arn
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "Karpenter-${module.eks.cluster_name}"
  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    AWSXrayWriteOnlyAccess       = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  }

  tags = var.tags
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.karpenter_version
  values = [
    templatefile("${path.module}/helm_values/karpenter_helm_values.yaml",
      {
        clusterName            = "${module.eks.cluster_name}",
        clusterEndpoint        = "${module.eks.cluster_endpoint}",
        interruptionQueueName  = "${module.karpenter.queue_name}",
        eks_amazonaws_role_arn = "${module.karpenter.iam_role_arn}",
        apiKey                 = "${var.datadog_api_key}",
        appKey                 = "${var.datadog_app_key}",
        env                    = "${var.env}",
        version                = "${local.karpenter_version}",
        datadog_sidecar        = indent(4, "${local.datadog_sidecar_deifinition}")
      }
    )
  ]
  depends_on = [module.karpenter, module.eks]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
      namespace: karpenter
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
        KarpenerProvisionerName: "default"
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  for_each  = local.spark_role_nodepool_nodetype_mapping
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: ${each.key}
      namespace: "karpenter"
      labels:
        type: karpenter
        provisioner: default
        NodeGroupType: ${each.key}
    spec:
      template:
        metadata:
          labels:
            type: karpenter
            provisioner: default
            NodeGroupType: ${each.key}
        spec:
          labels:
            type: karpenter
            provisioner: default
            NodeGroupType: ${each.key}
          nodeClassRef:
            name: default
          requirements:
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ${jsonencode(each.value.capacity_type)} #["spot", "on-demand"]
            - key: "karpenter.k8s.aws/instance-category" #If not included, all instance types are considered
              operator: In
              values: ${jsonencode(each.value.instance_category)} #["c", "m", "r"] 
            - key: "kubernetes.io/os"
              operator: In
              values: ${jsonencode(each.value.os)} #["amd64"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ${jsonencode(each.value.cpu)} #["4", "8", "16", "32"]

      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 1h
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
