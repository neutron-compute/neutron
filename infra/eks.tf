################################################################################
# EKS Module
################################################################################

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.2.1"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  # authentication_mode = "CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true
  kms_key_enable_default_policy            = false
  cluster_encryption_config                = {}
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = var.coredns_ver
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = var.kube_proxy_ver
    }
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = var.vpc_cni_ver
      service_account_role_arn = module.iam_assumable_role_with_oidc.iam_role_arn
    }
    aws-ebs-csi-driver = {
      addon_version            = var.aws_ebs_csi_driver_ver
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.ebs_csi_driver_role.iam_role_arn
    }
    amazon-cloudwatch-observability = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = var.amazon_cloudwatch_observability_ver
    }
    eks-pod-identity-agent = {
      resolve_conflicts = "OVERWRITE"
    }
  }
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_node_security_group              = false
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules
  fargate_profiles = {
    karpenter = {
      iam_role_additional_policies = {
        cludwatch_log_policy = aws_iam_policy.fargate_logging.arn
      }
      selectors = [
        {
          namespace = "karpenter"
        }
      ]
    }
    kube-system = {
      iam_role_additional_policies = {
        cludwatch_log_policy = aws_iam_policy.fargate_logging.arn
      }
      selectors = [
        {
          namespace = "kube-system"
        }
      ]
    }
    datadog = {
      iam_role_additional_policies = {
        cludwatch_log_policy = aws_iam_policy.fargate_logging.arn
      }
      selectors = [
        {
          namespace = "datadog"
        }
      ]
    }
    amazon-cloudwatch = {
      iam_role_additional_policies = {
        cludwatch_log_policy = aws_iam_policy.fargate_logging.arn
      }
      selectors = [
        {
          namespace = "amazon-cloudwatch"
        }
      ]
    }
  }
  cluster_enabled_log_types = ["audit", "api", "authenticator", "controllerManager", "scheduler", ]
  tags = merge(var.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.cluster_name
  })
}
