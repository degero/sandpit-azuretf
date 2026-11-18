# Administrator setup guide

## Requirements

- Subscription level contributor access
- AZ CLI logged in with target subscription set

## Terraform AzureRM authentication

use_azuread_auth = true
use_oidc = true

- OpenID Connect / Workload identity federation (Recommended by Hashicorp)
- User Assigned Managed Identity with Federated Credentials (Recommended by Hashicorp)

## Environment setup

1. Copy [scripts/administrators/.env.example](scripts/administrators/.env.example) to `scripts/administrators/.env` and update it with your Azure environment and target GitHub repositories.
1. Set up Terraform state storage and user-assigned managed identities with [scripts/administrators/setup-azure-tfstate-store.sh](scripts/administrators/setup-azure-tfstate-store.sh).
1. Set up GitHub environments, OIDC federated credentials, and environment variables with [scripts/administrators/setup-github-environments.sh](scripts/administrators/setup-github-environments.sh).
1. Optionally customize the OIDC subject claim with [scripts/administrators/setup-github-oidc-subject.sh](scripts/administrators/setup-github-oidc-subject.sh); see the security trade-off described in [scripts/administrators/README.md](scripts/administrators/README.md).
1. Update each GitHub environment variable `TF_PLAN_STORAGE_ACCOUNT` with the appropriate storage account name.
1. If enabling the docs workflow, add repository-level GitHub Actions secrets `DOCO_DEPLOY_KEY` (the private SSH deploy key used to push generated docs) and `INFRACOST_API_KEY`. The docs workflow does not target a GitHub Environment, so these are repository secrets rather than environment secrets.
1. If you want PRs to apply Terraform to the lowest (first) environment, set a repo variable `PR_TF_APPLY` to `true`.

#### Release Please

[Google's Release Please](https://github.com/googleapis/release-please) is run in workflows on main branch to compose CHANGELOG.md, repo tag versions and releases.

In GitHub, set **Settings → General → Pull Requests → Default commit message** to **Pull request title** so Release Please can compose release notes from PR titles correctly.

## Github Environments, Branch Protection and TF Service Principal guidelines

### GitHub environments and variables

Set the repository variable `TF_ENVIRONMENTS` to a JSON array of the environment directory names, for example `["dev"]`. Each name must match a directory under `environments/`; start with `["dev"]` and add environments as you create them.

For every configured environment, the workflows use two GitHub Environments:

- `<environment>-plan` is used by Terraform plan and drift-detection jobs. It normally does not require reviewers so plans can run automatically.
- `<environment>-apply` is used by Terraform apply jobs. Configure required reviewers and any other deployment protection rules for environments where an approval is required.

The GitHub setup script creates both environments and configures these environment variables on each:

- `AZURE_CLIENT_ID`: client ID of that environment's user-assigned managed identity.
- `AZURE_TENANT_ID`: Microsoft Entra tenant containing the deployment identity.
- `AZURE_SUBSCRIPTION_ID`: subscription targeted by Terraform deployments.
- `TF_PLAN_STORAGE_ACCOUNT`: storage account used to store Terraform plans.

The plan and apply environments use their corresponding identities. The workflows authenticate to Azure using GitHub OIDC; do not create or store a client secret for these identities. If you use the docs workflow in a generated repository, configure the repository-level `DOCO_DEPLOY_KEY` and `INFRACOST_API_KEY` secrets described above.

### Branch protection

Protect `main` separately from GitHub Environment approvals. Require pull requests and the CI checks appropriate for your repository, and restrict direct pushes and force pushes according to your team's policy. Environment reviewers gate deployments; branch protection controls changes to the branch and neither setting replaces the other.

### Terraform identities and Azure permissions

The bootstrap scripts create separate plan and apply user-assigned managed identities for each environment and federate them to the repository's GitHub Actions workflows. These managed identities have service principals in Microsoft Entra ID and authenticate through OIDC federation; no long-lived Azure credentials are stored in GitHub.

The bootstrap script grants `Contributor` at the deployment subscription and `Storage Blob Data Contributor` on the environment's state storage account to both identities as a simple starting point. This subscription-wide Contributor assignment is intentionally broad and is not recommended as a production permission model. Before production use, scope deployment permissions to the resources or resource group the environment manages, and grant plan and apply identities only the permissions each job needs. Keep state storage access limited to the required identities and developers.

For production environments, review the [AzureRM backend security guidance](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage). Consider private networking for storage, separate state and plan storage, and separate subscriptions for deployment environments and Terraform management infrastructure. See [Azure subscription democratization](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-principles#subscription-democratization) for guidance on subscription boundaries.

The bootstrap steps and security trade-offs are documented in [scripts/administrators/README.md](scripts/administrators/README.md).

## Linting and Formatters

Linting and Format checks are run in github workflows as well as pre-push.

If changing .sh/.ps1 scripts run:

```
shellcheck -S warning $(find . -type f -name "*.sh" -not -path "*/.terraform/*")
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning
```
