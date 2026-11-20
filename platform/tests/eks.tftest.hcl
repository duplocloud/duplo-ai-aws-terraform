# The eks module's own input checks (module.eks is stubbed in modes.tftest.hcl, so its variables aren't evaluated there).
# Mock-only: mocked resources get random ARNs that fail provider ARN validation.
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC" }
  }
  mock_resource "aws_eks_cluster" {
    defaults = {
      identity              = [{ oidc = [{ issuer = "https://oidc.mock/id/ABC" }] }]
      certificate_authority = [{ data = "Y2E=" }]
    }
  }
}
mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = { certificates = [{ sha1_fingerprint = "0000000000000000000000000000000000000000" }] }
  }
}

# Module-level checks: the eks module's own variable validation.
run "node_role_trust_refuses_every_service_account" {
  command = plan

  module {
    source = "../modules/eks"
  }

  variables {
    cluster_name                    = "acme-eks"
    vpc_id                          = "vpc-1"
    private_subnet_ids              = ["s1", "s2"]
    node_role_web_identity_subjects = ["system:serviceaccount:*:*"]
  }

  expect_failures = [var.node_role_web_identity_subjects]
}

run "public_endpoint_cidrs_must_be_cidrs" {
  command = plan

  module {
    source = "../modules/eks"
  }

  variables {
    cluster_name                 = "acme-eks"
    vpc_id                       = "vpc-1"
    private_subnet_ids           = ["s1", "s2"]
    endpoint_public_access_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.endpoint_public_access_cidrs]
}

run "defaults_keep_access_and_narrow_node_role_trust" {
  command = plan

  module {
    source = "../modules/eks"
  }

  variables {
    cluster_name       = "acme-eks"
    vpc_id             = "vpc-1"
    private_subnet_ids = ["s1", "s2"]
  }

  assert {
    condition     = strcontains(aws_iam_role.node.assume_role_policy, "system:serviceaccount:helpdesk:*") && !strcontains(aws_iam_role.node.assume_role_policy, "system:serviceaccount:*:*")
    error_message = "by default only the helpdesk namespace's service accounts may assume the node role"
  }
  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access && aws_eks_cluster.this.vpc_config[0].public_access_cidrs == toset(["0.0.0.0/0"])
    error_message = "the public endpoint stays open to the same addresses as before unless the deployment restricts it"
  }
}

run "no_web_identity_subjects_drops_the_statement" {
  command = plan

  module {
    source = "../modules/eks"
  }

  variables {
    cluster_name                    = "acme-eks"
    vpc_id                          = "vpc-1"
    private_subnet_ids              = ["s1", "s2"]
    node_role_web_identity_subjects = []
    endpoint_public_access_cidrs    = ["203.0.113.0/24"]
  }

  assert {
    condition     = !strcontains(aws_iam_role.node.assume_role_policy, "AssumeRoleWithWebIdentity")
    error_message = "an empty subject list removes the node role's web-identity trust"
  }
  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].public_access_cidrs == toset(["203.0.113.0/24"])
    error_message = "endpoint_public_access_cidrs restricts the public endpoint"
  }
}
