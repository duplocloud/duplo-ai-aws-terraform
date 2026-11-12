# Mock-only: mocked resources get random ARNs that fail provider ARN validation.
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_eks_cluster_auth" {
    defaults = { token = "mock-token" }
  }
}
mock_provider "helm" {}
# Mock-only: the mock cannot honour `length`, so assertions check the configured length.
mock_provider "random" {}
# Mock-only: the ingress status is only known after the ALB controller reconciles.
mock_provider "kubernetes" {
  mock_data "kubernetes_ingress_v1" {
    defaults = {
      status = [{
        load_balancer = [{
          ingress = [{ hostname = "k8s-helpdesk-abc.us-east-1.elb.amazonaws.com", ip = "" }]
        }]
      }]
    }
  }
}

override_data {
  target = data.terraform_remote_state.platform
  values = {
    outputs = {
      vpc_id                         = "vpc-1"
      private_subnet_ids             = ["s1", "s2"]
      public_subnet_ids              = ["p1", "p2"]
      cluster_name                   = "acme-eks"
      cluster_endpoint               = "https://mock.eks.example"
      cluster_ca_certificate         = "Y2E="
      oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
      oidc_provider_url              = "oidc.mock/id/ABC"
      node_sg_id                     = "sg-node"
      cluster_sg_id                  = "sg-cluster"
      alb_sg_id                      = "sg-alb"
      node_role_name                 = "acme-eks-node-role"
      efs_id                         = "fs-123"
      bucket_arn                     = "arn:aws:s3:::acme-bucket"
      userdata_bucket_arn            = "arn:aws:s3:::acme-userdata"
      bucket_name                    = "acme-bucket"
      userdata_bucket_name           = "acme-userdata"
      certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
      certificate_validation_records = []
      route53_zone_id                = "Z123"
      dns_mode                       = "route53"
    }
  }
}

variables {
  deployment = {
    name       = "acme"
    region     = "us-east-1"
    host       = "helpdesk.example.com"
    xterm_host = "xterm.example.com"
    account_id = "123456789012"
  }
  state = {
    bucket       = "duplo-helpdesk-tfstate-123456789012"
    region       = "us-east-1"
    platform_key = "deployments/acme/platform.tfstate"
  }
  addons = { mode = "create", values = {} }
  helpdesk = {
    mode = "create"
    values = {
      local_admin_email = "admin@example.com"
    }
  }
  secrets = {
    licensing_token      = "lic-token-value"
    local_admin_password = "pa,ss\\word"
  }
  common_tags = { owner = "test" }
}

run "addons_create" {
  command = apply

  assert {
    condition     = length(module.addons) == 1
    error_message = "addons module should be created in create mode"
  }
  assert {
    condition     = module.addons[0].external_dns_enabled == true
    error_message = "external-dns should be enabled when the platform has a Route53 zone"
  }
  assert {
    condition     = module.helpdesk.release_name == "duplo-ai-helpdesk"
    error_message = "helpdesk module should be planned"
  }
}

run "addons_existing" {
  command = apply

  variables {
    addons = { mode = "existing", values = {} }
  }

  assert {
    condition     = length(module.addons) == 0
    error_message = "addons module must not be created for existing add-ons"
  }
  assert {
    condition     = module.helpdesk.release_name == "duplo-ai-helpdesk"
    error_message = "helpdesk module must still be planned when add-ons are adopted"
  }
}

run "external_dns_off_when_not_route53" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "acme-eks"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        node_role_name                 = "acme-eks-node-role"
        efs_id                         = "fs-123"
        bucket_arn                     = "arn:aws:s3:::acme-bucket"
        userdata_bucket_arn            = "arn:aws:s3:::acme-userdata"
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = []
        route53_zone_id                = "Z123"
        dns_mode                       = "certificate"
      }
    }
  }

  assert {
    condition     = module.addons[0].external_dns_enabled == false
    error_message = "external-dns must be off when the platform has no Route53 zone"
  }
}

run "local_login" {
  command = apply

  assert {
    condition     = contains(module.helpdesk.values_preview_keys, "backend.extraEnv.Authentication__LocalAdminEmail")
    error_message = "local login must set Authentication__LocalAdminEmail in backend extraEnv"
  }
  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "backend.extraEnv.Authentication__LocalAdminPassword")
    error_message = "local admin password must be passed as a sensitive value"
  }
  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "secrets.licensingToken")
    error_message = "licensing token must be passed as a sensitive value"
  }
  assert {
    condition     = strcontains(module.helpdesk.rendered_values, "authSuperUsers: admin@example.com")
    error_message = "local admin email must be added to auth super users"
  }
  assert {
    condition     = !strcontains(module.helpdesk.rendered_values, "lic-token-value") && !strcontains(module.helpdesk.rendered_values, "pa,ss")
    error_message = "secrets must not be rendered into the values document"
  }
}

run "ignores_a_saved_login_method" {
  command = apply

  variables {
    helpdesk = {
      mode = "create"
      values = {
        login_method      = "google"
        google_client_id  = "gid"
        auth_super_users  = "someone@example.com"
        local_admin_email = "admin@example.com"
      }
    }
    secrets = {
      licensing_token      = "lic-token-value"
      local_admin_password = "pw"
      google_client_secret = "gsecret"
    }
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).config.authSuperUsers == "admin@example.com"
    error_message = "A login_method or auth_super_users saved by an older release is ignored; the local admin is the one super user."
  }
  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).secrets.googleClientId == "" && !contains(module.helpdesk.sensitive_value_labels, "secrets.googleClientSecret")
    error_message = "Google sign-in must stay off."
  }
  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "backend.extraEnv.Authentication__LocalAdminPassword")
    error_message = "The local admin password must still be passed."
  }
}

run "no_values_file" {
  command = apply

  assert {
    condition     = !contains(keys(module.helpdesk), "values_file_path") && !contains(keys(module.addons[0]), "values_file_path")
    error_message = "no module may expose a values_file_path output"
  }
}

run "route53_mode_has_no_dns_records" {
  command = apply

  assert {
    condition     = length(output.dns_records) == 0
    error_message = "dns_records must be empty in route53 mode"
  }
}

run "external_dns_mode" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "acme-eks"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        node_role_name                 = "acme-eks-node-role"
        efs_id                         = "fs-123"
        bucket_arn                     = "arn:aws:s3:::acme-bucket"
        userdata_bucket_arn            = "arn:aws:s3:::acme-userdata"
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = [{ name = "_a.helpdesk.example.com.", type = "CNAME", value = "_b.acm-validations.aws." }]
        route53_zone_id                = ""
        dns_mode                       = "external"
      }
    }
  }

  assert {
    condition     = !contains(keys(module.helpdesk), "certificate_validation_enabled") && !contains(keys(module.helpdesk), "certificate_arn_validated")
    error_message = "the app root must not wait for certificate validation (the backend waits for ISSUED)"
  }
  assert {
    condition     = length(output.dns_records) == 2 && alltrue([for r in output.dns_records : r.type == "CNAME" && r.value == output.load_balancer_hostname])
    error_message = "dns_records must be CNAMEs for both hosts pointing at the load balancer"
  }
  assert {
    condition     = output.helpdesk_url == "https://helpdesk.example.com"
    error_message = "helpdesk_url should be https://<host>"
  }
}

run "generated_and_secret_outputs" {
  command = apply

  assert {
    condition     = random_password.jwt_shared_secret.length >= 32 && random_password.mongodb_root_password.length >= 24 && nonsensitive(length(output.generated.jwt_shared_secret) > 0 && length(output.generated.mongodb_root_password) > 0)
    error_message = "random secrets should be generated"
  }
  assert {
    condition     = nonsensitive(output.secrets.licensing_token) == "lic-token-value"
    error_message = "secrets output should echo var.secrets"
  }
  assert {
    condition     = output.load_balancer_hostname == "k8s-helpdesk-abc.us-east-1.elb.amazonaws.com"
    error_message = "load_balancer_hostname should come from the ingress status"
  }
}

run "rejects_missing_admin_email" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = {} }
  }

  expect_failures = [var.helpdesk]
}

run "local_login_requires_password" {
  command = plan

  variables {
    secrets = { licensing_token = "lic-token-value" }
  }

  expect_failures = [var.secrets]
}

run "adopted_bucket_without_arn" {
  command = plan

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "acme-eks"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        node_role_name                 = "acme-eks-node-role"
        efs_id                         = "fs-123"
        bucket_arn                     = null
        userdata_bucket_arn            = ""
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = []
        route53_zone_id                = "Z123"
        dns_mode                       = "route53"
      }
    }
  }

  assert {
    condition     = length(module.addons) == 1
    error_message = "addons must plan with adopted buckets that have no ARN"
  }
}

run "dns_records_empty_until_lb_known" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "acme-eks"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        node_role_name                 = "acme-eks-node-role"
        efs_id                         = "fs-123"
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = []
        route53_zone_id                = ""
        dns_mode                       = "external"
      }
    }
  }

  override_data {
    target = module.helpdesk.data.kubernetes_ingress_v1.helpdesk
    values = { status = [] }
  }

  assert {
    condition     = output.load_balancer_hostname == "" && length(output.dns_records) == 0
    error_message = "dns_records must be empty until the load balancer hostname is known"
  }
}

# Destroy must still plan when the platform state is partial or gone (interrupted platform apply, or
# the platform root destroyed first): every platform output is read through try().
run "plans_without_platform_outputs" {
  command = plan

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {}
    }
  }

  assert {
    condition     = local.platform.cluster_name == "acme-eks" && local.dns_mode == ""
    error_message = "missing platform outputs must default instead of failing evaluation"
  }
}
