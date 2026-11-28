locals {
  # Bedrock actions for the LLM role the backend assumes per ticket turn (the Bedrock LLM provider). Matches the ai-ops
  # install skill's agent policy, plus Converse*. The agent's own role, a fallback when no LLM provider is set up,
  # keeps inference only.
  bedrock_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:Converse",
    "bedrock:ConverseStream",
    "bedrock:GetFoundationModel",
    "bedrock:GetFoundationModelAvailability",
    "bedrock:ListInferenceProfiles",
    "bedrock:GetInferenceProfile",
    "bedrock:CreateInferenceProfile",
    "bedrock:Rerank",
    "bedrock:ApplyGuardrail",
    "bedrock:GetGuardrail",
    "bedrock:ListGuardrails",
  ]

  # IRSA trust policies for each DuploCloud AI service account
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

# ── DuploCloud AI Backend IRSA (sts:AssumeRole on provider roles in any account)
# Not scoped to a role-name prefix or to this account: the backend assumes
# customer-created roles registered as cloud providers, which may live in
# any AWS account (e.g. a customer's dev/prod accounts), under any name.
# The target account's own trust policy is what actually gates access.
#
# It also carries the DuploCloud AI bucket access, so the backend works even when
# the node role (owned by the platform / adopted cluster) is left untouched.
#
# It also carries the helpdesk-VPC permissions for Network baselines' automatic VPC
# peering (DUPLOAI-5870). Pods can't reach IMDS on these nodes (IMDSv2, hop limit 1), so
# the backend finds its own VPC through the EC2 API: the ENI that owns the pod IP, then
# that VPC's CIDRs. Once a new network's stack requests peering, the backend accepts it
# and adds the return routes in the helpdesk VPC. Describe* calls can't be scoped to a
# resource; the calls that change things are limited to this VPC.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  ec2_arn_prefix   = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  helpdesk_vpc_arn = "${local.ec2_arn_prefix}:vpc/${var.vpc_id}"

  # A filtered for-expression, not `cond ? [] : [...]`: the two statements have different
  # object shapes, which a conditional can't unify with an empty tuple.
  helpdesk_vpc_peering_statements = [for s in [
    {
      Sid      = "HelpdeskVpcAcceptPeering"
      Effect   = "Allow"
      Action   = ["ec2:AcceptVpcPeeringConnection", "ec2:DeleteVpcPeeringConnection"]
      Resource = ["${local.ec2_arn_prefix}:vpc-peering-connection/*", local.helpdesk_vpc_arn]
      Condition = {
        ArnEquals = { "ec2:AccepterVpc" = local.helpdesk_vpc_arn }
      }
    },
    {
      Sid      = "HelpdeskVpcPeeringRoutes"
      Effect   = "Allow"
      Action   = ["ec2:CreateRoute", "ec2:DeleteRoute"]
      Resource = "${local.ec2_arn_prefix}:route-table/*"
      Condition = {
        ArnEquals = { "ec2:Vpc" = local.helpdesk_vpc_arn }
      }
    },
  ] : s if var.vpc_id != ""]
}

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
        },
        {
          Sid    = "HelpdeskVpcDiscovery"
          Effect = "Allow"
          Action = [
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeVpcs",
            "ec2:DescribeRouteTables",
            "ec2:DescribeVpcPeeringConnections"
          ]
          Resource = "*"
        }
      ],
      local.helpdesk_vpc_peering_statements,
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

# ── DuploCloud AI Agent IRSA (Bedrock inference) ──────────────────────────────
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

# ── Bedrock LLM role (first-run setup's LLM provider, DUPLOAI-5822) ─────────────
# First-run setup registers a Bedrock LLM provider with this role. Each ticket turn the backend assumes it (its own
# IRSA role already allows sts:AssumeRole) and hands the agent short-lived credentials. Only the backend role may
# assume it. No ExternalId condition: the trust names one role in this account, so there is no confused deputy.
locals {
  llm_bedrock_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.helpdesk_backend.arn }
      Action    = "sts:AssumeRole"
    }]
  })
  llm_bedrock_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "BedrockInference"
      Effect   = "Allow"
      Action   = local.bedrock_actions
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "helpdesk_llm_bedrock" {
  name               = "${var.cluster_name}-helpdesk-llm-bedrock-role"
  assume_role_policy = local.llm_bedrock_trust_policy
}

resource "aws_iam_policy" "helpdesk_llm_bedrock" {
  name   = "${var.cluster_name}-helpdesk-llm-bedrock-policy"
  policy = local.llm_bedrock_policy
}

resource "aws_iam_role_policy_attachment" "helpdesk_llm_bedrock" {
  role       = aws_iam_role.helpdesk_llm_bedrock.name
  policy_arn = aws_iam_policy.helpdesk_llm_bedrock.arn
}

resource "aws_iam_role" "helpdesk_analytics_collector" {
  name               = "${var.cluster_name}-helpdesk-analytics-collector-role"
  assume_role_policy = local.irsa_analytics_collector_trust
}

