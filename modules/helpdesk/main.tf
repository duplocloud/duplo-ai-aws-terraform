locals {
  # IRSA trust policies for each Helpdesk service account
  irsa_backend_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_backend_sa_namespace
    service_account   = var.helpdesk_backend_sa_name
  })

  irsa_agent_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_agent_sa_namespace
    service_account   = var.helpdesk_agent_sa_name
  })

  irsa_bedrock_subscription_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.bedrock_subscription_namespace
    service_account   = var.bedrock_subscription_sa_name
  })

  irsa_analytics_collector_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_analytics_collector_sa_namespace
    service_account   = var.helpdesk_analytics_collector_sa_name
  })
}

# ── Bedrock Subscription IRSA ────────────────────────────────────────────────
resource "aws_iam_policy" "bedrock_subscription" {
  name = "${var.cluster_name}-bedrock-subscription-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MarketplaceSubscription"
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe",
          "aws-marketplace:Unsubscribe"
        ]
        Resource = "*"
      },
      {
        Sid    = "BedrockSubscription"
        Effect = "Allow"
        Action = [
          "bedrock:CreateFoundationModelAgreement",
          "bedrock:ListFoundationModelAgreementOffers"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "bedrock_subscription" {
  name               = "${var.cluster_name}-bedrock-subscription-role"
  assume_role_policy = local.irsa_bedrock_subscription_trust
}

resource "aws_iam_role_policy_attachment" "bedrock_subscription" {
  role       = aws_iam_role.bedrock_subscription.name
  policy_arn = aws_iam_policy.bedrock_subscription.arn
}

# ── Helpdesk Backend IRSA (sts:AssumeRole on provider roles in any account) ───
# Not scoped to a role-name prefix or to this account: the backend assumes
# customer-created roles registered as cloud providers, which may live in
# any AWS account (e.g. a customer's dev/prod accounts), under any name.
# The target account's own trust policy is what actually gates access.
#
# It also carries the Helpdesk bucket access, so the backend works even when
# the node role (owned by the platform / adopted cluster) is left untouched.
resource "aws_iam_policy" "helpdesk_backend" {
  name = "${var.cluster_name}-helpdesk-backend-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AssumeRoleDuploCloud"
          Effect   = "Allow"
          Action   = "sts:AssumeRole"
          Resource = "arn:aws:iam::*:role/*"
        }
      ],
      var.s3_bucket_arn != "" && var.s3_userdata_bucket_arn != "" ? [
        {
          Sid    = "HelpdeskBuckets"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            var.s3_bucket_arn,
            "${var.s3_bucket_arn}/*",
            var.s3_userdata_bucket_arn,
            "${var.s3_userdata_bucket_arn}/*"
          ]
        }
      ] : []
    )
  })
}

resource "aws_iam_role" "helpdesk_backend" {
  name               = "${var.cluster_name}-helpdesk-backend-role"
  assume_role_policy = local.irsa_backend_trust
}

resource "aws_iam_role_policy_attachment" "helpdesk_backend" {
  role       = aws_iam_role.helpdesk_backend.name
  policy_arn = aws_iam_policy.helpdesk_backend.arn
}

# ── Helpdesk Agent IRSA (Bedrock inference) ───────────────────────────────────
resource "aws_iam_policy" "helpdesk_agent_bedrock" {
  name = "${var.cluster_name}-helpdesk-agent-bedrock-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInference"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Converse",
          "bedrock:ConverseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "helpdesk_agent_bedrock" {
  name               = "${var.cluster_name}-helpdesk-agent-bedrock-role"
  assume_role_policy = local.irsa_agent_trust
}

resource "aws_iam_role_policy_attachment" "helpdesk_agent_bedrock" {
  role       = aws_iam_role.helpdesk_agent_bedrock.name
  policy_arn = aws_iam_policy.helpdesk_agent_bedrock.arn
}

resource "aws_iam_role" "helpdesk_analytics_collector" {
  name               = "${var.cluster_name}-helpdesk-analytics-collector-role"
  assume_role_policy = local.irsa_analytics_collector_trust
}

