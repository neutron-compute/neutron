variable "env" {
  type        = string
  description = "The environment this pipeline will execute in "
  default     = "dev"
}

variable "region" {
  type        = string
  description = "AWS Region to default resources into"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_ami_id" {
  description = "Node AMI id of the EKS cluster"
  type        = string
  default     = "ami-0a728a56442124f5c"
}

variable "coredns_ver" {
  description = "coredns version of the EKS cluster"
  type        = string
  default     = "v1.11.1-eksbuild.6"
}

variable "kube_proxy_ver" {
  description = "kube-proxy version of the EKS cluster"
  type        = string
  default     = "v1.28.4-eksbuild.4"
}

variable "vpc_cni_ver" {
  description = "vpc-cni version of the EKS cluster"
  type        = string
  default     = "v1.16.2-eksbuild.1"
}

variable "aws_ebs_csi_driver_ver" {
  description = "aws-ebs-csi-driver version of the EKS cluster"
  type        = string
  default     = "v1.27.0-eksbuild.1"
}

variable "amazon_cloudwatch_observability_ver" {
  description = "amazon-cloudwatch-observability version of the EKS cluster"
  type        = string
  default     = "v1.2.1-eksbuild.1"
}

variable "eks_pod_identity_ver" {
  description = "amazon-cloudwatch-observability version of the EKS cluster"
  type        = string
  default     = "v1.2.0-eksbuild.1"
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned. If `control_plane_subnet_ids` is not provided, the EKS cluster control plane (ENIs) will be provisioned in these subnets"
  type        = list(string)
}

variable "enable_karpenter_discovery_tag" {
  type        = bool
  description = "if the subnets are shared from another account the additional tagging for discovery might not be there"
  default     = false
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster and its nodes will be provisioned"
  type        = string
}

variable "additional_rbac_config" {
  description = "List of user maps to add to the aws-auth configmap"
  type        = list(any)
  default     = []
}

variable "eks_endpoint_whitelist" {
  description = "Whitelisted CIDR ranges for EKS endpoint ingress traffic"
  type        = list(string)
  default     = []
}

variable "eks_ssh_whitelist" {
  description = "Whitelisted CIDR ranges for EKS ssh traffic"
  type        = list(string)
  default     = []
}

variable "k8s_worker_additional_userdata" {
  description = "Additional script to be appended to all EC2 userdata scripts"
  type        = string
  default     = ""
}

variable "k8s_worker_instance_type" {
  type = string
  # m4.xlarge gives us max 58 pods per node:
  # https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt
  default     = "m4.xlarge"
  description = "Instance type for the main K8S node group"
}

variable "k8s_worker_asg_max_size" {
  type        = number
  default     = 10
  description = "Max cluster size for the main K8S node group"
}

variable "k8s_worker_asg_min_size" {
  type        = number
  default     = 1
  description = "Min cluster size for the main K8S node group"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "block_device_mappings" {
  description = "Specify volumes to attach to the instance besides the volumes specified by the AMI"
  type        = any
  default     = {}
}

variable "aws_auth_roles" {
  description = "Extra AWS auth roles"
  type        = list(any)
  default     = []
}

variable "aws_auth_fargate_profile_pod_execution_role_arns" {
  description = "List of Fargate profile pod execution role ARNs to add to the aws-auth configmap"
  type        = list(string)
  default     = []
}

### Spark namespace and roles variables

variable "spark_roles" {
  type        = map(any)
  description = "the config for all the spark job roles we need to create with their respective policies"
}


### Fargate Logging

variable "enable_fargate_logging" {
  type    = bool
  default = true
}


#### Datadog monitoring
variable "enable_datadog" {
  type    = bool
  default = false
}

variable "datadog_api_key" {
  type    = string
  default = ""
}

variable "datadog_app_key" {
  type    = string
  default = ""
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_security_group_additional_rules" {
  description = "List of additional security group rules to add to the cluster security group created. Set `source_node_security_group = true` inside rules to set the `node_security_group` as source"
  type        = any
  default     = {}
}

########placementd variables#######################

##########placementd rds variables################

variable "placementd_rds_cidr" {
  description = "additional cidrs to have access to placementd rds "
  type        = list(string)
  default     = []
}

variable "placementd_rds_name" {
  type        = string
  description = "placementd RDS name"
  default     = "placementd-rds"
}

variable "placementd_rds_engine_version" {
  type        = string
  description = "placementd engine version"
  default     = "16.1"
}

variable "placementd_rds_engine" {
  type        = string
  description = "placementd RDS engine"
  default     = "aurora-postgresql"
}

variable "placementd_rds_group_family" {
  type        = string
  description = "placementd RDS group family"
  default     = "aurora-postgresql16"
}

variable "placementd_rds_backup_retention_period" {
  type        = number
  description = "placementd RDS backup retention period"
  default     = "30"
}

variable "placementd_rds_instances" {
  type        = map(any)
  description = "contains placementd RDS instances"
  default = {
    1 = {
      identifier     = "placementd-postgres-node-1"
      instance_class = "db.t3.medium"
    }
  }
}

variable "placementd_kms_alias" {
  description = "KMS customer master key alias, that allows DBencryption"
  type        = string
  default     = "alias/placementd-rds"
}


#######################placementd ecs cluster variables##############
variable "placementd_ecs_cluster_name" {
  type        = string
  description = "placementd RDS name"
  default     = "placementd-ecs"
}

variable "fargate_spot_capacity_provider_weight" {
  type        = string
  description = "describe your variable"
  default     = "50"
}
variable "fargate_capacity_provider_weight" {
  type        = string
  description = "describe your variable"
  default     = "50"
}
variable "placementd_ingress_cidr_blocks" {
  type        = list(any)
  description = "describe your variable"
  default     = ["0.0.0.0/0"]
}

