# terraform-aws-helpdesk

OpenTofu / Terraform code that deploys [DuploCloud](https://duplocloud.com) **Helpdesk** into your own AWS
account: a VPC, an EKS cluster, EFS and S3 storage, an HTTPS certificate with DNS, the cluster add-ons, and
the Helpdesk Helm release.

Every layer can be **created** or can **adopt** something you already have (an existing VPC, cluster,
file system, bucket or certificate). Adopted resources are read, never modified. So the same code serves a
greenfield account and an account with an established platform.

This repository is used on its own, and it is also what the DuploCloud DevKit's Cloud Deployment agent
runs. The agent pins a release of this repo and generates its setup wizard from these variables.

## Layout

```
platform/     root 1: everything created through the AWS API (state: platform.tfstate)
app/          root 2: everything created through the Kubernetes API (state: app.tfstate)
modules/
  vpc/        network layer      public and private subnets in three zones, NAT gateway
  eks/        cluster layer      EKS cluster, managed node group, OIDC provider, cluster-admin access entry
  efs/        efs layer          encrypted EFS file system with mount targets in the private subnets
  s3/         buckets layer      app-data and user-data buckets, encrypted, no public access
  dns/        dns layer          ACM certificate, optional Route 53 records
  addons/     addons layer       AWS Load Balancer Controller, EFS CSI driver, external-dns, storage classes
  helpdesk/   helpdesk layer     namespace, IAM roles for service accounts, the Helpdesk Helm release
```

There are two roots because the `app` root configures the Helm and Kubernetes providers from a cluster
that must already exist. Apply `platform` first, then `app`. The `app` root reads the platform outputs
from the platform state with `terraform_remote_state`.

## Requirements

- OpenTofu 1.10 or later (S3 native state locking). Terraform 1.10+ also works but is not tested here.
- AWS credentials with administrator access in the target account. For an adopted cluster, the credentials
  must have cluster-admin on it.
- An S3 bucket for state.
- A DuploCloud Helpdesk license token.

## Inputs

Both roots take one object per layer:

```hcl
network = {
  mode     = "create"        # or "existing"
  values   = { ... }         # optional module arguments, by variable name
  provides = { ... }         # for "existing": the adopted resource's identifiers
}
```

With `mode = "create"` the layer's module runs, with `values` overriding its defaults. Every module
variable has a sensible default, so `values = {}` works. With an adopt mode, the module is not
instantiated and the root uses `provides` instead.

| Layer | Root | Modes | `provides` for adopt modes |
|---|---|---|---|
| `network` | platform | `create`, `existing` | `vpc_id`, `private_subnet_ids`, `public_subnet_ids` |
| `cluster` | platform | `create`, `existing` | `cluster_name`, `cluster_endpoint`, `cluster_ca_certificate`, `oidc_provider_arn`, `oidc_provider_url`, `node_sg_id`, `cluster_sg_id`, `node_role_name`, optional `alb_sg_id` |
| `efs` | platform | `create`, `existing` | `efs_id` |
| `buckets` | platform | `create`, `existing` | `bucket_name`, `bucket_arn`, optional `userdata_bucket_name`, `userdata_bucket_arn` |
| `dns` | platform | `route53` (certificate + Route 53 records, `values.route53_zone_name`), `certificate` (existing ACM certificate), `external` (certificate only; you create the DNS records) | `certificate_arn` (for `certificate`) |
| `addons` | app | `create`, `existing` | none |
| `helpdesk` | app | `create` | none |

Other inputs:

- `deployment` (both roots): `{ name, region, host, xterm_host, account_id }`. `host` and `xterm_host` are
  the Helpdesk hostnames.
- `state` (app root): `{ bucket, region, platform_key }`, where the platform state lives.
- `secrets` (app root, sensitive map): `licensing_token`, `local_admin_password`; optional `slack_app_token`,
  `slack_bot_token`. Pass it as `TF_VAR_secrets` so it never lands in a file.
- Sign-in is the local admin only (`helpdesk.values.local_admin_email` and `secrets.local_admin_password`).
  The local admin is a super user, along with any admin emails in `helpdesk.values.auth_super_users`
  (comma-separated). Google and Microsoft sign-in are not offered; a saved `login_method` other than `local`
  is rejected with a migration message.
- `common_tags` (both roots): tags for every resource.

The module variables (`modules/*/variables.tf`) are the full list of `values` each layer accepts, with
descriptions and defaults.

## Usage

Greenfield example inputs are in [`examples/greenfield/`](examples/greenfield/).

```bash
# 1. platform
cd platform
cat > backend.hcl <<EOF
bucket       = "my-tofu-state"
key          = "helpdesk/platform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
EOF
tofu init -backend-config=backend.hcl
tofu plan  -var-file=../examples/greenfield/platform.tfvars.json -out=platform.tfplan
tofu apply platform.tfplan

# 2. if dns mode is "external": create the certificate validation records shown in the
#    certificate_validation_records output and wait until the ACM certificate is ISSUED

# 3. app
cd ../app
sed 's/platform.tfstate/app.tfstate/' ../platform/backend.hcl > backend.hcl
tofu init -backend-config=backend.hcl
export TF_VAR_secrets='{"licensing_token":"...","local_admin_password":"..."}'
tofu plan  -var-file=../examples/greenfield/app.tfvars.json -out=app.tfplan
tofu apply app.tfplan
tofu output helpdesk_url
```

Destroy in the reverse order: `app`, then `platform`. Adopted resources are left untouched.

## Outputs

`platform`: network, cluster, storage and certificate identifiers (`vpc_id`, `cluster_name`,
`cluster_endpoint`, `efs_id`, `bucket_name`, `certificate_arn`, `certificate_validation_records`,
`dns_mode`, and more; see `platform/outputs.tf`). `app`: `helpdesk_url`, `load_balancer_hostname`,
`dns_records` (the records to create when DNS is external), and the sensitive `secrets` and `generated`.

## Security

- Secrets enter only through the sensitive `secrets` variable. Nothing is written to local files, and Helm
  values are passed in memory.
- The JWT shared secret and the MongoDB root password are generated (`random_password`) and kept in state.
  Protect the state bucket accordingly (encryption, versioning, restricted access).
- Provider versions and checksums are pinned by the committed `.terraform.lock.hcl` in each root.

## Tests

```bash
cd platform && tofu init -backend=false && tofu test
cd ../app   && tofu init -backend=false && tofu test
```

The tests use mock providers and cover every layer mode; they need no AWS account.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Changes must keep existing deployments upgradeable; the rules are
listed there.

## License

Apache License 2.0. See [LICENSE](LICENSE).
