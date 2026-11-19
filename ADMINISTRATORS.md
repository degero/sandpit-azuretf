# Administrator setup guide

This guide takes an administrator from an empty Azure subscription and GitHub repository to a working Terraform CI/CD pipeline. For what each bootstrap script does internally, and the tools they need, see [scripts/administrators/README.md](scripts/administrators/README.md).

## How it fits together

Workflows authenticate to Azure with GitHub OIDC and Workload Identity Federation (`use_oidc = true`, `use_azuread_auth = true`), as recommended by HashiCorp. No client secrets or storage keys are stored in GitHub.

For each environment (for example `dev`, `test`, `prod`) the bootstrap creates:

- A resource group with a storage account holding Terraform state (`tfstate`) and saved plans (`tfplans`).
- Two user-assigned managed identities, one for plan and one for apply, federated to this repository's workflows.
- Two GitHub Environments, `<env>-plan` and `<env>-apply`, so approval can be controlled separately for plan and apply.

## Prerequisites

- Azure: you can create resource groups, storage accounts and managed identities, and you can assign roles. Subscription **Owner** or **User Access Administrator** is needed for the role assignments.
- Local tools: `az`, `gh`, `openssl` and Bash. See [scripts/administrators/README.md](scripts/administrators/README.md#dependencies).
- Logged in to both: `az login` (with the target subscription set) and `gh auth login`.

## Setup steps

## Run bootstrap scripts for Azure TF infra and GitHub

Run everything from `scripts/administrators/`.

1. **Configure.** Copy `.env.example` to `.env` read the comments and fill in your tenant, subscription, location, environment names (`ENVS`, max 8, the order matters, it should always be lowest to highest) and target repositories (`GITHUB_REPOS`). See below step #3 if you want more fine grained OIDC auth with setting `ADD_ENVIRONMENT_SUBJECT_CLAIM`
2. **Create Azure state storage and identities.**
   ```bash
   ./setup-azure-tfstate-store.sh
   ```
   Make note of the output. It lists the storage account name and resource group for each environment, and appends `TFPLAN_STORAGE_ACCOUNTS` to `.env` for use in the below scripts.
3. **Set the GitHub OIDC subject template.**
   ```bash
   ./setup-github-oidc-subject.sh
   ```
   Run this before the next step. The federated credentials are pinned to the workflow (and optionally the environment with .env `ADD_ENVIRONMENT_SUBJECT_CLAIM` = true), which only matches if the repository's OIDC subject template includes those claims. This follows recommended structure for securing this auth but you can inspect and change how fine-grained this subject is. You can view this setting in github under actions > oidc.
4. **Create GitHub environments, federated credentials and variables.**

   ```bash
   ./setup-github-environments.sh
   ```

5. **Add `backend.hcl` and `terraform.tfvars` for each environment (both required).** In `environments/<env>/`:
   - Copy `backend.hcl.example` to `backend.hcl` and fill in details output from step 2. Leve `container_name = "tfstate"`, and use a unique `key` per environment. ⚠️ Do not add access keys, SAS tokens or client secrets! ⚠️
   - Copy `terraform.tfvars.example` to `terraform.tfvars` and set `environment` to match the directory name, `projectname` (used for azure resource naming), and `location` from step 2. All these values are required and should be defined. ⚠️ Only add non-sensitive values ⚠️
     CI runs `terraform init -backend-config="backend.hcl"` and `terraform plan -var-file=terraform.tfvars`, so both files must be committed. Both are in `.gitignore` on purpose (`backend.hcl`, and `*.tfvars` which is a catch-all for files that may hold sensitive data), so users don't accidentally alter or commit changes to them. You must force-add them:

```bash
git add -f environments/<env>/backend.hcl environments/<env>/terraform.tfvars
```

6. **Update workflows and README.md your own repository.** `main.yml` and `pr.yml` call `tf-plan.yml` and `tf-apply.yml` by full repository path at `@main`. In a repo created from the template, replace the template's relative path with yours:

```bash
REPO="your-owner/your-repo"
sed -i.bak -E "s#uses: \./\.github/workflows/(tf-plan|tf-apply)\.yml#uses: ${REPO}/.github/workflows/\1.yml@main#" .github/workflows/main.yml .github/workflows/pr.yml
rm .github/workflows/*.bak
sed -i.bak "s#OWNER/REPOSITORY#${REPO}#g" README.md
rm README.md.bak
```

This is required for OIDC login. The federated credentials are pinned to `job_workflow_ref` = `<owner>/<repo>/.github/workflows/tf-<plan|apply>.yml@refs/heads/main`. Calling the workflow by full path at `@main` keeps that claim identical for PR and `main` runs, whereas a relative `./` call reports the caller's ref (`refs/pull/N/merge` on PRs), failing main.yml and pr.yml

7. **Set GitHub Environment approval rules.** In GitHub, add required reviewers to each `<env>-apply` environment where an approval is needed. `<env>-plan` normally has no reviewers so plans run automatically.
8. **Optional: docs workflow.** Add repository secrets `DOCO_DEPLOY_KEY` (used to push generated docs, it needs to have write access, to create see [managing deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys)) and `INFRACOST_API_KEY`. The docs workflow does not target a GitHub Environment, so these are repository secrets, not environment secrets.
9. **Pull request behaviour (optional).** Pull requests run Terraform plan for every environment but do **not** apply by default. To also apply the lowest (first) environment in `TF_ENVIRONMENTS` on PRs, set the repository variable `PR_TF_APPLY` to `true`. Apply is skipped for PRs from forks, and still runs in the `<env>-apply` GitHub Environment, so any required reviewers there still gate it.
10. **CHANGELOG.md** In **Github → Settings → General → Pull Requests**, set **Default commit message** to **Pull request title**. Also Delete the current `CHANGELOG.md` from the repo and update `cliff.toml` `commit_preprocessors`, `postprocessors` sections for links to PRs to appear in the `CHANGELOG.md`. Git cliff in changelog.yml workflow runs on `main` and composes `CHANGELOG.md` from PR titles so long as developers follow [Conventional Commits](https://www.conventionalcommits.org/) guidelines, guidance for devs is in [DEVELOPERS.md](DEVELOPERS.md#conventional-commits).
11. **Code and Dependency Scanning** In **Github → Settings → Advanced Security** turn on **Dependabot → Alerts, Malware Updates, Security updates** and **Code Security → CodeQL Analysis** to make use of the repos dependabot.yml and codeql.yml workflows. The latter is only available in public repos and paid github accounts. CodeQL SARIF upload is disabled by default. To enable, set a repo env var `ENABLE_SARIF_UPLOAD` = `true`.

### Adding an environment later

Run `./setup-github-environments.sh <new-env>` (this also appends it to `ENVS` in `.env`), but only after `setup-azure-tfstate-store.sh` has provisioned it. Then add `environments/<new-env>/` with its `backend.hcl` (force-added, as in step 5), and set approval rules on `<new-env>-apply`.

### Cleanup

It is recommended to remove the .example files and scripts/administrators once setup is done.

## GitHub configuration reference

### Repository variable

- `TF_ENVIRONMENTS`: JSON array of environment directory names, for example `["dev","test","prod"]`. Each name must match a directory under `environments/` the order matters, it should always be lowest to highest. The setup script sets this for you, always listing the full `ENVS` set.

### Environment variables

Set on each `<env>-plan` and `<env>-apply` environment by the setup script:

| Variable                  | Value                                                      |
| ------------------------- | ---------------------------------------------------------- |
| `AZURE_CLIENT_ID`         | Client ID of that stage's managed identity (plan or apply) |
| `AZURE_TENANT_ID`         | Entra tenant of the deployment identity                    |
| `AZURE_SUBSCRIPTION_ID`   | Subscription targeted by Terraform                         |
| `TF_PLAN_STORAGE_ACCOUNT` | Storage account holding saved plans                        |

### Branch protection

Protect `main` separately from environment approvals. Require pull requests and the CI checks suited to your repository, and restrict direct and force pushes per your team's policy. Environment reviewers gate deployments, branch protection gates changes to the branch, and neither replaces the other.

## Recommended security hardening before production

These provided admin scripts are designed for simplicity and is **not** a production permission model.

- **Broad roles.** Both identities get `Contributor` on the whole deployment subscription, plus `Storage Blob Data Contributor` on their environment's storage account. Scope these to the resources or resource group each environment manages, and give plan and apply identities only what each job needs. A plan identity should not need write access.
- **Public storage network.** Storage accounts allow network access from anywhere (authentication is still required, and shared-key and public blob access are disabled). Use private networking with VNET-integrated runners (ACI/ACA) for production.
- **State and plan storage.** Consider separating them, and limiting access to the required identities and developers.
- **Subscriptions.** Consider separate subscriptions for deployment environments and Terraform management infrastructure. See [subscription democratization](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-principles#subscription-democratization).
- **OIDC subject scope.** By default the subject is pinned to repository owner ID, repository ID and workflow, but not to the GitHub environment, so Dependabot and GitHub Advanced Security keep working. Set `ADD_ENVIRONMENT_SUBJECT_CLAIM="true"` in `.env` for stricter environment-level pinning, at the cost of those features, then re-run steps 3 and 4.
- **Github Deploy Keys** This is used for ease of setup for the doco.yml workflow to write files to the repo. It is recommended to review and use an alternative that suits your security posture.

Further reading: [AzureRM backend security guidance](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage).

## Linting and formatters

Lint and format checks run in GitHub workflows and pre-push. If you change `.sh` or `.ps1` scripts, run:

```
shellcheck -S warning $(find . -type f -name "*.sh" -not -path "*/.terraform/*")
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning
```
