# Mock-only: mocked resources get random ARNs that fail provider ARN validation.
# Mock-only: a mocked ACM certificate has unknown validation options, which breaks for_each.
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC" }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
      domain_validation_options = [
        {
          domain_name           = "helpdesk.example.com"
          resource_record_name  = "_a.helpdesk.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_b.acm-validations.aws."
        },
        {
          domain_name           = "xterm.example.com"
          resource_record_name  = "_c.xterm.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_d.acm-validations.aws."
        }
      ]
    }
  }
}
mock_provider "tls" {}

# Mock-only: the aws_eks_cluster mock cannot express its nested blocks, so the
# eks module's outputs are stubbed rather than computed from the mocked cluster.
override_module {
  target = module.eks
  outputs = {
    cluster_name           = "acme-eks"
    cluster_endpoint       = "https://mock.eks.example"
    cluster_ca_certificate = "Y2E="
    oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/oidc.mock/id/ABC"
    oidc_provider_url      = "oidc.mock/id/ABC"
    node_sg_id             = "sg-node"
    eks_cluster_sg_id      = "sg-cluster"
    node_role_name         = "acme-eks-node-role"
    alb_sg_id              = "sg-alb"
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
  network = { mode = "create", values = {}, provides = {} }
  cluster = { mode = "create", values = {}, provides = {} }
  efs     = { mode = "create", values = {}, provides = {} }
  buckets = { mode = "create", values = {}, provides = {} }
  dns = {
    mode     = "route53"
    values   = { route53_zone_name = "example.com" }
    provides = {}
  }
  common_tags = { owner = "test" }
}

override_data {
  target = data.aws_availability_zones.available
  values = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
}

run "greenfield" {
  command = apply

  assert {
    condition     = length(module.vpc) == 1
    error_message = "vpc module should be created"
  }
  assert {
    condition     = length(module.eks) == 1
    error_message = "eks module should be created"
  }
  assert {
    condition     = length(module.dns) == 1
    error_message = "dns module should be created"
  }
  assert {
    condition     = module.dns[0].route53_record_count == 2 && module.dns[0].validated
    error_message = "route53 mode must create validation records and validate the certificate"
  }
  assert {
    condition     = length(module.efs) == 1 && length(module.s3) == 1
    error_message = "efs and s3 modules should be created"
  }
  assert {
    condition     = output.dns_mode == "route53"
    error_message = "dns_mode output should echo the dns layer mode"
  }
  assert {
    condition     = output.alb_sg_id == "sg-alb"
    error_message = "alb_sg_id should come from the eks module when created"
  }
}

run "existing_network" {
  command = apply

  variables {
    network = {
      mode   = "existing"
      values = {}
      provides = {
        vpc_id             = "vpc-1"
        private_subnet_ids = ["s1", "s2"]
        public_subnet_ids  = ["p1", "p2"]
      }
    }
  }

  assert {
    condition     = length(module.vpc) == 0
    error_message = "vpc module must not be created for existing network"
  }
  assert {
    condition     = output.vpc_id == "vpc-1"
    error_message = "vpc_id should come from provides"
  }
  assert {
    condition     = output.private_subnet_ids == ["s1", "s2"] && output.public_subnet_ids == ["p1", "p2"]
    error_message = "subnet ids should come from provides"
  }
}

run "existing_cluster" {
  command = apply

  variables {
    network = {
      mode   = "existing"
      values = {}
      provides = {
        vpc_id             = "vpc-1"
        private_subnet_ids = ["s1", "s2"]
        public_subnet_ids  = ["p1", "p2"]
      }
    }
    cluster = {
      mode   = "existing"
      values = {}
      provides = {
        cluster_name           = "c1"
        cluster_endpoint       = "https://c1.example"
        cluster_ca_certificate = "Y2E="
        oidc_provider_arn      = "arn:aws:iam::123456789012:oidc-provider/oidc.example/id/ABC"
        oidc_provider_url      = "oidc.example/id/ABC"
        node_sg_id             = "sg-node"
        cluster_sg_id          = "sg-cluster"
        node_role_name         = "node-role"
        alb_sg_id              = "sg-alb-existing"
      }
    }
  }

  assert {
    condition     = length(module.eks) == 0
    error_message = "eks module must not be created for existing cluster"
  }
  assert {
    condition     = output.oidc_provider_arn == "arn:aws:iam::123456789012:oidc-provider/oidc.example/id/ABC"
    error_message = "oidc_provider_arn should come from provides"
  }
  assert {
    condition     = output.cluster_name == "c1" && output.node_sg_id == "sg-node" && output.cluster_sg_id == "sg-cluster" && output.node_role_name == "node-role"
    error_message = "cluster outputs should come from provides"
  }
  assert {
    condition     = output.alb_sg_id == "sg-alb-existing"
    error_message = "alb_sg_id should come from provides for an existing cluster"
  }
}

run "dns_external" {
  command = apply

  variables {
    dns = { mode = "external", values = {}, provides = {} }
  }

  assert {
    condition     = length(module.dns) == 1
    error_message = "dns module should be created in external mode"
  }
  assert {
    condition     = module.dns[0].route53_record_count == 0
    error_message = "external mode must not create any aws_route53_record"
  }
  assert {
    condition     = !module.dns[0].validated
    error_message = "external mode must not create aws_acm_certificate_validation"
  }
  assert {
    condition     = length(module.dns[0].validation_records) > 0
    error_message = "external mode must emit validation records"
  }
  assert {
    condition     = length(output.certificate_validation_records) > 0
    error_message = "root must surface validation records"
  }
  assert {
    condition     = output.route53_zone_id == ""
    error_message = "external mode has no hosted zone"
  }
  assert {
    condition     = output.dns_mode == "external"
    error_message = "dns_mode output should be external"
  }
}

run "dns_certificate" {
  command = apply

  variables {
    dns = {
      mode     = "certificate"
      values   = {}
      provides = { certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/provided" }
    }
  }

  assert {
    condition     = length(module.dns) == 0
    error_message = "dns module must not be created when a certificate is provided"
  }
  assert {
    condition     = output.certificate_arn == "arn:aws:acm:us-east-1:123456789012:certificate/provided"
    error_message = "certificate_arn should come from provides"
  }
}
