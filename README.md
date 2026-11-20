# Azure Terraform Template

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/degero/sandpit-azuretf/badge)](https://scorecard.dev/viewer/?uri=github.com/degero/sandpit-azuretf)
[![CI](https://github.com/degero/sandpit-azuretf/actions/workflows/main.yml/badge.svg)](https://github.com/degero/sandpit-azuretf/actions/workflows/main.yml)
[![CodeQL](https://github.com/degero/sandpit-azuretf/actions/workflows/codeql.yml/badge.svg)](https://github.com/degero/sandpit-azuretf/actions/workflows/codeql.yml)
[![CSpell check](https://github.com/degero/sandpit-azuretf/actions/workflows/cspell.yml/badge.svg)](https://github.com/degero/sandpit-azuretf/actions/workflows/cspell.yml)
[![Lint](https://github.com/degero/sandpit-azuretf/actions/workflows/lint.yml/badge.svg)](https://github.com/degero/sandpit-azuretf/actions/workflows/lint.yml)
[![Terraform Drift Detection](https://github.com/degero/sandpit-azuretf/actions/workflows/tf-drift.yml/badge.svg)](https://github.com/degero/sandpit-azuretf/actions/workflows/tf-drift.yml)

> After creating a repository from this template, replace `degero/sandpit-azuretf` in these above badge > URLs with its GitHub owner and repository name. GitHub does not automatically rewrite
> README links when generating a repository from a template.

## Description

An opinionated GitHub template for developing Terraform running multi env infra deployments in Azure.

This template is focused on the terraform and GitHub CICD it is not opinionated on the Azure hosted terraform management infrastructure as this can vary greatly by organisation. Scripts are included to get a baseline running, however no hardening is included again for the same reason.

```text
/
├── environments/ - each target azure environment has its own subfolder to reduce blast radius
├── modules/ - Terraform modules used by environments
├── modulesgroups/ - Grouping of Terraform modules in /modules
├── scripts/ - Az CLI scripts to setup terraform remote state store and github actions access to azure
└── tests/ - For cross module tests
```

## Key components

- Isolated /environments/env-name root terraform modules to reduce blast radius / increased flexibility
- Github environments matching tf environments for approval control
- Isolated terraform federated credentials + 2 UAMI per env (plan,apply) + RBAC to blob storage by environment (tfstate, tfplans containers)
- Isolated GitHub OIDC and Workload Identity Federation for Terraform AzureRM backend operations (see [ADMINISTRATORS.md](ADMINISTRATORS.md) for details on adjustable OIDC subject)

- TFPlan artifacts uploaded to blob storage tfplans container (retention 7 days) for terraform apply workflows to use
- Github Workflows with:
  - Security Checks: Checkov, Trivy, CodeQL(SARIF Artifact option), Gitleaks(PR Comments, SARIF Artifact option)
  - Dependabot: Terraform, Github Actions
  - Validation: Terraform Plan (change summary/failure output PR comment), Terraform Validate, Drift Detection (scheduled)
  - Testing: Terraform Test(artifact, test summary PR comment)
  - Linting: Tflint, Actionlint, Prettier (markdown,yaml,json(c)), Terraform Fmt, Scripts(PSScriptAnalyzer, shellcheck)
  - Documentation generation: terraform-docs, Infracost monthly-cost estimates, terravision diagram (to /docs)
  - Changelog generation: git-cliff
  - Misc: CSpell, OpenSSF Scorecard
- `terraform.workspace` guard prevents local runs from writing to the CI-owned `default` workspace
- Atomic modules in `/modules`, composite module groups in `/modulegroups`, and cross-module tests in `/tests`, modules dont use `main.tf` name for easy location in vscode
- VSCode settings for format on save: terraform, markdown, yaml, json(c), powershell
- Named Terraform files instead of repeated `main.tf` files for easier discovery in VS Code
- Dev Container tooling for Terraform, Azure CLI, GitHub CLI, TFLint, Checkov, Trivy, documentation and graph tools, Prettier, CSpell, Gitleaks, ShellCheck, PSScriptAnalyzer, and Actionlint
- `/scripts` folder for dev convenience (tfinit, tftest) and admin setup Azure terraform infra / github settings.

## Terraform module structure

Terraform modules are broken out based on Terraform Best Practices [Medium Size Infrastructure](https://www.terraform-best-practices.com/examples/terraform/medium-size-infrastructure). It can be adjusted as needed but it is recommended to at least keep the 'environments' structure which fites in with the Blast Radius / Terraform state store / Deployment principal isolation.

```text
environments/ ←
├── dev(test,stage,prod,etc)/
│ ├── terraform.tfvars
│ ├── backend.hcl
│ └── main.tf # root module for ENV calls modules/, and compositions/ etc.

modules/ ← atomic modules only (one resource type each + unit test file)
├── compute/
│ ├── functionapp/functionapp.tf
│ └── vm/vm.tf
├── storage/
│ └── account/storageaccount.tf
├── networking/
│ ├── vnet/vnet.tf
│ └── subnet/subnet.tf
├── secrets/
│ └── keyvault/keyvault.tf

modulegroups/ ← composite modules (patterns of primitives)
├── function-app-order-process/
└─── function-app-order-process.tf # calls modules/compute/functionapp + modules/storage/account

tests/ (Add cross module / integration tests here)
```

## Setup and development

Administrators see [ADMINISTRATORS.md](./ADMINISTRATORS.md).
Developers see [DEVELOPERS.md](./DEVELOPERS.md)

## Links

https://www.terraform-best-practices.com/examples/terraform/medium-size-infrastructure

https://developer.hashicorp.com/terraform/language/backend/azurerm
