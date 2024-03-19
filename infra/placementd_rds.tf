data "aws_availability_zones" "available" {}

resource "aws_db_subnet_group" "placementd_db_subnet" {
  name        = "rds-${var.env}-${var.placementd_rds_name}"
  subnet_ids  = var.subnet_ids
  description = "placementd RDS subnet"
  tags        = merge(var.tags, { "Name" = "rds-${var.env}-${var.placementd_rds_name}" })
}

data "aws_iam_policy_document" "placementd_rds_encrypt_cmk_data" {
  version = "2012-10-17"
  statement {
    sid    = "Allow access through RDS for all principals in the account that are authorized to use RDS"
    effect = "Allow"
    actions = ["kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.us-east-2.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  statement {
    sid    = "Allow direct access to key metadata to the account"
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }
}

resource "aws_kms_key" "placementd_rds_encrypt_kms" {
  description             = "Provides a customer master key, that allows encryption at rest for the Aurora database."
  deletion_window_in_days = 30
  tags                    = var.tags
  policy                  = data.aws_iam_policy_document.placementd_rds_encrypt_cmk_data.json
}

resource "aws_kms_alias" "placementd_rds_alias" {
  name          = var.placementd_kms_alias
  target_key_id = aws_kms_key.placementd_rds_encrypt_kms.key_id
}


module "placementd_rds" {
  create                      = true
  source                      = "terraform-aws-modules/rds-aurora/aws"
  version                     = "8.5.0"
  name                        = var.placementd_rds_name
  engine                      = var.placementd_rds_engine
  engine_version              = var.placementd_rds_engine_version
  manage_master_user_password = true
  vpc_id                      = var.vpc_id
  availability_zones          = data.aws_availability_zones.available.names
  db_subnet_group_name        = try(aws_db_subnet_group.placementd_db_subnet.name, "")
  create_db_subnet_group      = false
  master_username             = "placementd_admin"
  ca_cert_identifier          = "rds-ca-rsa2048-g1"
  security_group_rules = {
    cidr_ingress_ex = {
      cidr_blocks = var.placementd_rds_cidr
    }
    security_group_ingress_ex = {
      source_security_group_id = module.eks.cluster_primary_security_group_id
    }
  }
  instances                              = var.placementd_rds_instances
  backup_retention_period                = var.placementd_rds_backup_retention_period
  preferred_backup_window                = "07:00-09:00"
  copy_tags_to_snapshot                  = true
  preferred_maintenance_window           = "Sat:20:30-Sat:21:30"
  apply_immediately                      = true
  skip_final_snapshot                    = false
  deletion_protection                    = false
  publicly_accessible                    = false # this provides access into RDS in private subnets
  kms_key_id                             = try(aws_kms_key.placementd_rds_encrypt_kms.arn, "")
  storage_encrypted                      = true
  create_db_cluster_parameter_group      = true
  db_cluster_parameter_group_name        = var.placementd_rds_name
  db_cluster_parameter_group_family      = var.placementd_rds_group_family
  db_cluster_parameter_group_description = "${var.placementd_rds_name} cluster parameter group"
  create_db_parameter_group              = true
  db_parameter_group_name                = var.placementd_rds_name
  db_parameter_group_family              = var.placementd_rds_group_family
  db_parameter_group_description         = "${var.placementd_rds_name} DB parameter group"
  auto_minor_version_upgrade             = false
  cloudwatch_log_group_retention_in_days = 30
  create_cloudwatch_log_group            = true
  tags                                   = var.tags
}
