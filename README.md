# Azure Terraform Template

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/OWNER/REPOSITORY/badge)](https://scorecard.dev/viewer/?uri=github.com/OWNER/REPOSITORY)
[![CI](https://github.com/OWNER/REPOSITORY/actions/workflows/main.yml/badge.svg)](https://github.com/OWNER/REPOSITORY/actions/workflows/main.yml)
[![CodeQL](https://github.com/OWNER/REPOSITORY/actions/workflows/codeql.yml/badge.svg)](https://github.com/OWNER/REPOSITORY/actions/workflows/codeql.yml)
[![CSpell check](https://github.com/OWNER/REPOSITORY/actions/workflows/cspell.yml/badge.svg)](https://github.com/OWNER/REPOSITORY/actions/workflows/cspell.yml)
[![Lint](https://github.com/OWNER/REPOSITORY/actions/workflows/lint.yml/badge.svg)](https://github.com/OWNER/REPOSITORY/actions/workflows/lint.yml)
[![Terraform Drift Detection](https://github.com/OWNER/REPOSITORY/actions/workflows/tf-drift.yml/badge.svg)](https://github.com/OWNER/REPOSITORY/actions/workflows/tf-drift.yml)

> After creating a repository from this template, replace `OWNER/REPOSITORY` in these above badge > URLs with its GitHub owner and repository name. GitHub does not automatically rewrite
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
- Isolated terraform federated credentials + 2 UMAI per env (plan,apply) + RBAC to blob storage by environment (tfstate, tfplans containers)
- TFPlan artifacts uploaded to blob storage (retention 7 days)
- Named `/modules` files for easy location in VSCode (instead of lots of main.tf files)
- Github Workflows with: Linting (tflint,actionlint,prettier), Formatting (terraform fmt), Sec checks (checkov, Gitleaks secret scanning with PR comments and SARIF artifact), Github Environments for workflow approval, Dependabot (terraform, github actions), Doco generation (terraform-docs), Terraform Validate, Drift Detection (automated scheduled checks + issue management)
- Pre-push githook to validate/format terraform, lint (prettier,actionlint,powershell,shellscript) and checkov (if installed) locally
- VSCode settings for format on save: markdown / yaml / json(c), powershell
- Prettier rules for markdown / yaml / json(c)
- Scripts folder for dev convenience (tfinit) and admin setup Azure terraform infra / github settings.

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
