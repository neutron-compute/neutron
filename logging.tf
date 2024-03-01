#### this file is to config logging for all the fargate profiles
locals {
  fargate_logging_config = {
    output_conf  = <<-EOF
    [OUTPUT]
      Name cloudwatch_logs
      Match kube.*
      region ${var.region}
      log_group_name ${module.eks.cloudwatch_log_group_name}/fargate-fluentbit-logs
      log_stream_prefix from-fluent-bit-
      log_retention_days 60
      auto_create_group true
    EOF
    filters_conf = <<-EOF
    [FILTER]
        Name parser
        Match *
        Key_name log
        Parser crio
    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On
        Keep_Log Off
        Buffer_Size 0
        Kube_Meta_Cache_TTL 300s
    EOF
    parsers_conf = <<-EOF
    [PARSER]
        Name crio
        Format Regex
        Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<log>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    EOF
  }
}

data "aws_iam_policy_document" "fargate_logging" {
  policy_id = "replication0"
  statement {
    resources = [
      "*"
    ]
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy"
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "fargate_logging" {
  name   = "fargate_logging"
  policy = data.aws_iam_policy_document.fargate_logging.json
  tags   = var.tags
}

resource "kubernetes_namespace_v1" "fargate_logging" {
  count = var.enable_fargate_logging ? 1 : 0
  metadata {
    annotations = {
      name = "aws-observability"
    }
    labels = {
      aws-observability = "enabled"
    }
    name = "aws-observability"
  }
}

# fluent-bit-cloudwatch value as the name of the CloudWatch log group that is automatically created as soon as your apps start logging
resource "kubernetes_config_map" "fargate_logging" {
  count = var.enable_fargate_logging ? 1 : 0
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace_v1.fargate_logging[0].id
  }

  data = {
    "parsers.conf" = local.fargate_logging_config["parsers_conf"]
    "filters.conf" = local.fargate_logging_config["filters_conf"]
    "output.conf"  = local.fargate_logging_config["output_conf"]
  }
}
