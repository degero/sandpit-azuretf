# Administrator bootstrap scripts

Reference for the scripts in this folder: what they need and exactly what they do. For the step-by-step setup procedure, see [ADMINISTRATORS.md](../../ADMINISTRATORS.md).

Run order: `setup-azure-tfstate-store.sh`, then `setup-github-oidc-subject.sh`, then `setup-github-environments.sh`.

## Dependencies

### Tools

| Tool | Used by | Notes |
|---|---|---|
| Bash | all scripts | Uses arrays, `[[ ]]`, `${BASH_SOURCE}` and `set -euo pipefail`. On Windows use Git Bash or WSL. |
| `az` (Azure CLI) | `setup-azure-tfstate-store.sh`, `setup-github-environments.sh` | Logged in with rights to create resource groups, storage accounts, identities and federated credentials, and to assign roles. |
| `gh` (GitHub CLI) | `setup-github-environments.sh`, `setup-github-oidc-subject.sh` | Authenticated, with admin rights on the target repos. The scripts exit if it is missing or unauthenticated. |
| `openssl` | `setup-azure-tfstate-store.sh` | Generates the random storage account suffix. |
| coreutils, `sed` | all scripts | `tr`, `head`, `cat`, `dirname`, `rm`, and `sed -i.bak` (works on GNU and macOS). |

### Network

Azure Resource Manager and Entra, `api.github.com`, and `token.actions.githubusercontent.com` (the federated credential issuer).

### Local files

- **`.env`** in this folder, copied from `.env.example`. All scripts source it, except `setup-github-oidc-subject.sh` when given a single `owner/repo` argument.
- **Scripts write to `.env`.** `setup-azure-tfstate-store.sh` appends `TFPLAN_STORAGE_ACCOUNTS`, and `setup-github-environments.sh` rewrites the `ENVS` line when given new environment names.
- **`policy.json`** is written to the current working directory by `setup-azure-tfstate-store.sh` and is not removed afterwards. Run the scripts from a directory where that is acceptable.

### `.env` settings

| Variable | Purpose |
|---|---|
| `ENVS` | Space-separated environment names, max 8. |
| `GITHUB_REPOS` | Space-separated `owner/repo` list trusted to assume the identities. |
| `LOCATION`, `RGPREFIX`, `STORAGE_SKU` | Azure region, resource group name prefix, storage SKU. |
| `ADD_ENVIRONMENT_SUBJECT_CLAIM` | `true` adds the GitHub environment to the OIDC subject. Must be set (scripts run with `set -u`). Defaults to `false` in the example. |
| `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | Deployment target. Set on every GitHub environment. |
| `BACKEND_STORAGE_TENANT_ID`, `BACKEND_STORAGE_SUBSCRIPTION_ID` | Where state storage and identities are created. May differ from the deployment target. |
| `TFPLAN_STORAGE_ACCOUNTS` | Written by the first script, required by the second. Do not set by hand. |

## setup-azure-tfstate-store.sh

For each name in `ENVS`:

1. Creates resource group `$RGPREFIX-$env` in `$LOCATION`.
2. Creates storage account `sttfstate$env<6 random chars>` with: no public blob access, TLS 1.2 minimum, shared-key access disabled, infrastructure encryption on, network default action **Allow**, and an `environment` tag.
3. Creates blob containers `tfstate` and `tfplans` (using Entra login auth).
4. Applies a lifecycle policy deleting blobs under `tfplans/` 7 days after creation.
5. Creates user-assigned managed identities `id-terraform-cicd-plan-$env` and `id-terraform-cicd-apply-$env`.
6. Assigns both identities `Contributor` on the deployment subscription, and `Storage Blob Data Contributor` on that environment's storage account.
7. Prints the values needed for `backend.hcl` (resource group, storage account name).

Finally appends `TFPLAN_STORAGE_ACCOUNTS="<space-separated names>"` to `.env`, in the same order as `ENVS`.

Notes:

- The printed block is headed "Github Env secrets" but these are set as GitHub **variables** by the next script. Its `AZURE_SUBSCRIPTION_ID` line also shows the backend subscription rather than the deployment subscription.
- The Contributor assignment is subscription-wide and intentionally broad. See the hardening section of [ADMINISTRATORS.md](../../ADMINISTRATORS.md#security-hardening-before-production).

## setup-github-oidc-subject.sh

Usage: `./setup-github-oidc-subject.sh [owner/repo]`

For each repo (the argument, or every entry in `GITHUB_REPOS`), validates the `owner/repo` format and sets the repository's OIDC subject claim template via the GitHub API (`use_default=false`), then reads it back to confirm. The included claim keys are:

- `repository_owner_id`, `repository_id`, `job_workflow_ref`
- plus `environment` when `ADD_ENVIRONMENT_SUBJECT_CLAIM=true`

This must match the subject format used for the federated credentials created by the next script, so re-run both if you change `ADD_ENVIRONMENT_SUBJECT_CLAIM`.

## setup-github-environments.sh

Usage: `./setup-github-environments.sh [new-env ...]`

- **No arguments:** provisions every environment in `ENVS` (initial setup).
- **With names:** appends them to `ENVS` in `.env` and provisions only those. Errors if a name already exists or if the total would exceed 8.

Requires `ENVS`, `GITHUB_REPOS`, `RGPREFIX`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TFPLAN_STORAGE_ACCOUNTS` to be set in `.env`.

Steps:

1. Sets repo variable `TF_ENVIRONMENTS` on each repo to the full JSON array of environments (including any just added).
2. For each target environment, looks up the plan and apply identities and their client IDs. Environments whose identities are not found are skipped with a warning.
3. For each repo, resolves the repo ID and owner ID, then for both `apply` and `plan` stages:
   - Creates federated credential `fic-github-<repo-slug>-<stage>-<env>` on the matching identity. Issuer is `https://token.actions.githubusercontent.com` and audience is `api://AzureADTokenExchange`.
   - The subject is `repository_owner_id:<id>:repository_id:<id>[:environment:<env>-<stage>]:job_workflow_ref:<repo>/.github/workflows/tf-<stage>.yml@refs/heads/main`. The environment part is included only when `ADD_ENVIRONMENT_SUBJECT_CLAIM=true`.
   - Creates the GitHub Environment `<env>-<stage>`.
   - Sets environment variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TF_PLAN_STORAGE_ACCOUNT`.

Notes:

- `TFPLAN_STORAGE_ACCOUNTS` is matched to environments **by position**, so its order must match `ENVS`. When adding environments, the order must match what `setup-azure-tfstate-store.sh` produced.
- Federated credential creation output is discarded (`&>/dev/null`), so failures there are silent. Check the identities in the Azure portal if auth fails later.
- Because workflow-pinned credentials reference `@refs/heads/main`, the workflows must run from `main`.
