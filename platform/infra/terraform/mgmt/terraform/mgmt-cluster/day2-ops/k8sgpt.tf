# Create IAM policy for Bedrock access
resource "aws_iam_policy" "k8sgpt_bedrock_policy" {
  name_prefix = "modern-engg-k8sgpt-bedrock-"
  description = "For use with k8sgpt integration"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create IAM role for k8sgpt to access Bedrock
module "k8sgpt-operator-controller-manager-role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_name_prefix = "modern-engg-k8sgpt-operator-"
  
  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.eks_oidc.arn
      namespace_service_accounts = ["k8sgpt-operator-system:k8sgpt"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "k8sgpt_operator_role_attach" {
  role       = module.k8sgpt-operator-controller-manager-role.iam_role_name
  policy_arn = aws_iam_policy.k8sgpt_bedrock_policy.arn
}

resource "kubernetes_manifest" "namespace_k8sgpt" {

  manifest = {
    "apiVersion" = "v1"
    "kind" = "Namespace"
    "metadata" = {
      "name" = "k8sgpt-operator-system"
    }
  }
}

resource "kubernetes_manifest" "serviceaccount_k8sgpt" {
  depends_on = [
    kubernetes_manifest.namespace_k8sgpt
  ]
  
  manifest = {
    "apiVersion" = "v1"
    "kind" = "ServiceAccount"
    "metadata" = {
      "annotations" = {
        "eks.amazonaws.com/role-arn" = tostring(module.k8sgpt-operator-controller-manager-role.iam_role_arn)
      }
      "name" = "k8sgpt"
      "namespace" = "k8sgpt-operator-system"
    }
  }
}

resource "kubectl_manifest" "application_argocd_k8sgpt_operator" {
  depends_on = [kubernetes_manifest.serviceaccount_k8sgpt] 
  yaml_body = templatefile("${path.module}/templates/argocd-apps/k8sgpt.yaml", {
     AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
     EKS_REGION = var.region
    }
  )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd application/k8sgpt-operator --timeout=300s"

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command = "kubectl wait --for=delete svc k8sgpt-operator-controller-manager-metrics-service -n k8sgpt-operator-system --timeout=300s"

    interpreter = ["/bin/bash", "-c"]
  }
}
