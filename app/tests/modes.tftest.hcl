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
      login_method      = "local"
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
    condition = yamldecode(module.helpdesk.rendered_values).upgrader.bootstrap == {
      enabled = true
      values  = { channels = { initialChannel = "hdst-stable" } }
    }
    error_message = "the upgrader hook is on and this install enrolls on hdst-stable"
  }
  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).clickhouse.persistence.storageClass == "gp3"
    error_message = "ClickHouse must request gp3: the cluster has no default StorageClass, so an empty class leaves its PVC Pending"
  }
  assert {
    condition     = !strcontains(module.helpdesk.rendered_values, "lic-token-value") && !strcontains(module.helpdesk.rendered_values, "pa,ss")
    error_message = "secrets must not be rendered into the values document"
  }
}

run "google_login" {
  command = apply

  variables {
    helpdesk = {
      mode = "create"
      values = {
        login_method     = "google"
        google_client_id = "gid"
      }
    }
    secrets = {
      licensing_token      = "lic-token-value"
      google_client_secret = "gsecret"
    }
  }

  assert {
    condition     = !contains(module.helpdesk.values_preview_keys, "backend.extraEnv.Authentication__LocalAdminEmail")
    error_message = "google login must not set local admin env"
  }
  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "secrets.googleClientSecret") && !contains(module.helpdesk.sensitive_value_labels, "backend.extraEnv.Authentication__LocalAdminPassword")
    error_message = "google login must pass only the google client secret"
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

run "rejects_unknown_login_method" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { login_method = "saml" } }
  }

  expect_failures = [var.helpdesk]
}

run "local_login_requires_password" {
  command = plan

  variables {
    secrets = { licensing_token = "lic-token-value" }
  }

  expect_failures = [var.helpdesk]
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

# The node permissions policy goes only on a node role the platform created (contract: adopt modes never modify
# the adopted resource).
run "node_permissions_on_created_node_role" {
  command = apply

  assert {
    condition     = module.addons[0].node_permissions_attached
    error_message = "a node role the platform created (no node_role_managed output: v0.1.1 state, default name) keeps the node permissions policy"
  }
}

run "node_permissions_not_on_adopted_node_role" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "c1"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        efs_id                         = "fs-123"
        bucket_arn                     = "arn:aws:s3:::acme-bucket"
        userdata_bucket_arn            = "arn:aws:s3:::acme-userdata"
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = []
        route53_zone_id                = "Z123"
        dns_mode                       = "route53"
        node_role_name                 = "c1-node-role"
        node_role_managed              = false
      }
    }
  }

  assert {
    condition     = !module.addons[0].node_permissions_attached
    error_message = "an adopted cluster's node role must not be modified, even when its name matches the created role's"
  }
}

run "node_permissions_on_managed_node_role" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "c1"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        efs_id                         = "fs-123"
        bucket_arn                     = "arn:aws:s3:::acme-bucket"
        userdata_bucket_arn            = "arn:aws:s3:::acme-userdata"
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = []
        route53_zone_id                = "Z123"
        dns_mode                       = "route53"
        node_role_name                 = "custom-role"
        node_role_managed              = true
      }
    }
  }

  assert {
    condition     = module.addons[0].node_permissions_attached
    error_message = "node_role_managed = true attaches the node permissions policy"
  }
}

run "node_permissions_not_on_unknown_node_role_of_old_state" {
  command = apply

  override_data {
    target = data.terraform_remote_state.platform
    values = {
      outputs = {
        vpc_id                         = "vpc-1"
        public_subnet_ids              = ["p1", "p2"]
        cluster_name                   = "c1"
        cluster_endpoint               = "https://mock.eks.example"
        cluster_ca_certificate         = "Y2E="
        oidc_provider_arn              = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
        oidc_provider_url              = "oidc.mock/id/ABC"
        alb_sg_id                      = "sg-alb"
        efs_id                         = "fs-123"
        bucket_arn                     = "arn:aws:s3:::acme-bucket"
        userdata_bucket_arn            = "arn:aws:s3:::acme-userdata"
        certificate_arn                = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
        certificate_validation_records = []
        route53_zone_id                = "Z123"
        dns_mode                       = "route53"
        node_role_name                 = "customer-node-role"
      }
    }
  }

  assert {
    condition     = !module.addons[0].node_permissions_attached
    error_message = "a v0.1.1 platform state with an adopted node role (name not the created role's) must not get the policy"
  }
}

# First-run setup (DUPLOAI-5822): the backend assumes a dedicated Bedrock role, and the chart learns its ARN.
run "first_run_setup_llm_role" {
  command = apply

  override_resource {
    target = module.helpdesk.aws_iam_role.helpdesk_backend
    values = { arn = "arn:aws:iam::123456789012:role/acme-backend" }
  }
  override_resource {
    target = module.helpdesk.aws_iam_role.helpdesk_llm_bedrock
    values = { arn = "arn:aws:iam::123456789012:role/acme-llm" }
  }

  assert {
    condition     = jsondecode(module.helpdesk.llm_bedrock_trust_policy).Statement[0].Principal == { AWS = "arn:aws:iam::123456789012:role/acme-backend" } && jsondecode(module.helpdesk.llm_bedrock_trust_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "only the backend role may assume the Bedrock LLM role"
  }
  assert {
    condition = yamldecode(module.helpdesk.rendered_values).firstRunSetup.llm.bedrock == {
      iamRoleArn = "arn:aws:iam::123456789012:role/acme-llm"
      region     = "us-east-1"
    }
    error_message = "the chart's first-run setup must get the Bedrock LLM role and region"
  }
  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).firstRunSetup.activeDeadlineSeconds == 840
    error_message = "first-run setup's Job deadline must use the helm_release timeout (900 s), not the chart's 5m-safe default"
  }
  assert {
    condition     = output.llm_bedrock_role_arn == "arn:aws:iam::123456789012:role/acme-llm"
    error_message = "the Bedrock LLM role ARN must be an output"
  }
  assert {
    condition = toset(jsondecode(module.helpdesk.llm_bedrock_policy).Statement[0].Action) == toset([
      "bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:Converse", "bedrock:ConverseStream",
      "bedrock:GetFoundationModel", "bedrock:GetFoundationModelAvailability", "bedrock:ListInferenceProfiles",
      "bedrock:GetInferenceProfile", "bedrock:CreateInferenceProfile", "bedrock:Rerank", "bedrock:ApplyGuardrail",
      "bedrock:GetGuardrail", "bedrock:ListGuardrails",
    ])
    error_message = "the Bedrock LLM role must carry the agent's Bedrock actions"
  }
  assert {
    condition = toset(jsondecode(module.helpdesk.agent_bedrock_policy).Statement[0].Action) == toset([
      "bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:Converse", "bedrock:ConverseStream",
    ])
    error_message = "the agent's own role keeps inference only; the wider list is for the LLM role"
  }
}

# First-run setup's provisioning token belongs to the first super user, and only the local admin exists when the
# chart's post-install hook runs, so the local admin must come first.
run "local_admin_is_first_super_user" {
  command = apply

  variables {
    helpdesk = {
      mode = "create"
      values = {
        login_method      = "local"
        local_admin_email = "admin@example.com"
        auth_super_users  = "ops@example.com"
      }
    }
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).config.authSuperUsers == "admin@example.com,ops@example.com"
    error_message = "the local admin must be the first auth super user"
  }
}
