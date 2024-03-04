module "spark_team_roles" {
  for_each                       = var.spark_roles
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "v5.33.1"
  create_role                    = true
  allow_self_assume_role         = true
  role_name                      = join("_", [module.eks.cluster_name, each.key])
  provider_url                   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns               = lookup(each.value, "policies", [])
  oidc_fully_qualified_subjects  = ["system:serviceaccount:${each.key}:${each.key}"]
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  tags                           = var.tags
}

resource "kubernetes_namespace_v1" "spark_team" {
  for_each = var.spark_roles
  metadata {
    name = each.key
  }
  timeouts {
    delete = "15m"
  }
}

resource "kubernetes_service_account_v1" "spark_team" {
  for_each = var.spark_roles
  metadata {
    name        = each.key
    namespace   = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    annotations = { "eks.amazonaws.com/role-arn" : module.spark_team_roles[each.key].iam_role_arn }
  }

  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "spark_team" {
  for_each = var.spark_roles
  metadata {
    name      = "${each.key}-secret"
    namespace = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name"      = kubernetes_service_account_v1.spark_team[each.key].metadata[0].name
      "kubernetes.io/service-account.namespace" = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

#---------------------------------------------------------------
# Kubernetes Cluster role for service Account 
#---------------------------------------------------------------
resource "kubernetes_cluster_role" "spark_role" {
  for_each = var.spark_roles
  metadata {
    name = "${each.key}-spark-cluster-role"
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["namespaces", "nodes", "persistentvolumes"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
  }
  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
    api_groups = [""]
    resources  = ["serviceaccounts", "services", "configmaps", "events", "pods", "pods/log", "persistentvolumeclaims"]
  }

  rule {
    verbs      = ["create", "patch", "delete", "watch"]
    api_groups = [""]
    resources  = ["secrets"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["nodes/metrics", "nodes/spec", "nodes/stats", "nodes/proxy", "nodes/pods", "nodes/healthz", "endpoints"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
    api_groups = ["extensions"]
    resources  = ["ingresses"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
  }

  depends_on = [module.spark_team_roles]
}
#---------------------------------------------------------------
# Kubernetes Cluster Role binding role for service Account 
#---------------------------------------------------------------
resource "kubernetes_cluster_role_binding" "spark_role_binding" {
  for_each = var.spark_roles
  metadata {
    name = "${each.key}-spark-cluster-role-bind"
  }

  subject {
    kind      = "ServiceAccount"
    name      = each.key
    namespace = each.key
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.spark_role[each.key].id
  }

  depends_on = [module.spark_team_roles]
}
