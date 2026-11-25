# Contributing

## Development

```bash
tofu fmt -recursive
cd platform && tofu init -backend=false && tofu validate && tofu test
cd ../app   && tofu init -backend=false && tofu validate && tofu test
cd .. && tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"
```

CI runs the same commands with OpenTofu 1.13.2 and TFLint 0.65.0 on every pull request.

## Reference implementation

This repository is the reference implementation for DuploCloud AI on OpenTofu / Terraform.
[`duplo-ai-gcp-terraform`](https://github.com/duplocloud/duplo-ai-gcp-terraform) and
[`duplo-ai-azure-terraform`](https://github.com/duplocloud/duplo-ai-azure-terraform) follow the same layout,
inputs and output names, and each documents in its own CONTRIBUTING.md where it differs. A change to the
rules below usually needs a matching change in those repositories.

## Compatibility rules

Tooling that deploys DuploCloud AI, including DuploCloud's managed deployment tooling, pins tagged releases of this
repository, reads the module variables and runs the two roots. Keep these properties so that existing
deployments and that tooling keep working:

- **Layout**: `platform/`, `app/`, `modules/<module>/` at the repo root. Roots reference modules as
  `../modules/<module>`. Each root has `versions.tf`, `backend.tf` with an empty `backend "s3" {}` block,
  `variables.tf`, `main.tf`, `outputs.tf`, `tests/`, and a committed `.terraform.lock.hcl`.
- **Layers**: `network`, `cluster`, `efs`, `buckets`, `dns` in `platform`; `addons`, `helpdesk` in `app`.
  Each is one root variable `{ mode, values, provides }`.
- **Modes**: `create` runs the layer's module (`count = 1`). An adopt mode runs it with `count = 0` and
  reads `var.<layer>.provides.<name>` instead. Adopt modes never create anything that changes the adopted
  resource.
- **Values**: roots pass module arguments as `try(var.<layer>.values.<name>, null)` so an omitted value
  falls back to the module default. Every module variable that a user can set has a `description`.
- **Root inputs**: `deployment` `{ name, region, host, xterm_host, account_id }`, `state` (app root),
  `secrets` (sensitive map, app root), `common_tags`.
- **Outputs**: the output names in `platform/outputs.tf` and `app/outputs.tf` are part of the public
  interface; do not rename or remove them.
- **No secrets on disk**: no `local_file`/`local_sensitive_file`; secrets only via `var.secrets`; generated
  secrets via `random_password`.
- **Plain OpenTofu / Terraform only**: no tool-specific UI or configuration files in this repository. The
  variable descriptions are the documentation for each input.

## Upgrade safety

Every release can reach existing deployments: a deployment that moves to a newer release picks up its changes
on the next plan. A user always reviews the plan before anything is applied, but a release must not make that
plan destructive for no reason.

- Renaming or moving a resource (including into or out of a module, or changing a `count`/`for_each` key)
  needs a `moved` block.
- A new variable must have a `default` (and `nullable = false` unless null means something). A deployment
  created with an older release must plan without new inputs.
- Removing or renaming a variable or an output, changing a variable's type, or a provider major version
  bump is a **breaking change**: list it under "Breaking changes" in the release notes.
- Do not change defaults that would replace existing resources (instance types, CIDRs, names) without a
  breaking-change note.

## Providers and lock files

After changing a `required_providers` block, regenerate the lock files for all supported platforms:

```bash
for r in platform app; do
  (cd $r && tofu init -backend=false -upgrade && tofu providers lock \
     -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64)
done
```

## Releases

Semver tags `vX.Y.Z` on `main`, never moved or deleted (deployments pin the tag and its commit SHA). The
GitHub release notes list, per module: variables added, removed or changed; outputs added or removed;
provider version changes; and a "Breaking changes" section (or "None").
