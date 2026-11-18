## Developer guide

### Prerequisites

- Terraform
- Azure CLI (logged in to tenant with remote storage)
- Role 'Storage Blob Data Contributor' on the DEV tfstate blob storage
- Role 'Contributor' on the lower-environment resource group (for example, `dev`) when testing Terraform changes from a local machine

(Optional for githook prepush)

- tflint
- Checkov
- PowerShell (pwsh) + PSScriptAnalyzer module
- ShellCheck
- actionlint
- Node.js (for npx → cspell, Prettier)

### Azure permissions for terraform management infra

If you have appropriate access, assign yourself access to the dev tfstate storage (otherwise contact your admin):

```bash
az ad signed-in-user show --query id -o tsv

az role assignment create \
  --assignee your-id \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>/blobServices/default/containers/tfstate"
```

NOTE: If state storage is in a different subscription or tenant you will need access to these.

### Development workflow:

```bash
(optional: the prepush check also done in CI) git config core.hooksPath .githooks

If you wish to run local plan runs on higher envs, set an env var "TF_PLUGIN_CACHE_DIR" for a common cache location

cd environments/dev (and other envs needing changes)
../../scripts/tf-init.sh/ps1 (convenience item as first init needs backend.hcl file)

terraform workspace new <issuenumber> (so workspace is unique)

# Make changes

terraform plan -out="tfplan"
(if you have access) terraform apply tfplan

# before committing changes run in repo root:

# after PR complete
terraform workspace select default
terraform workspace delete <issuenumber>

```

See [Release Please](#release-please) below for PR title guidelines.

It is recommended to use a workspace for local dev to not interfere with the tfstate used by CI or other devs.

It is recommended to setup a TF_PLUGIN_CACHE_DIR env var.

### Linting, Spelling and Formatters

Linting, Spelling and Format checks are run in github workflows as well as pre-push. Prettier is setup to format most files on save however...

If changing .tf files run:

```
terraform fmt -recursive -write
```

### Release Please

This repo uses [release-please](https://github.com/googleapis/release-please) to automate versioning and the changelog, which relies on [Conventional Commits](https://www.conventionalcommits.org/). As squash commits to main are enforced, which will drop a commit message using the conventions, please prefix the PR title with these instead:

| Prefix      | Use for                                                 | Version bump                |
| ----------- | ------------------------------------------------------- | --------------------------- |
| `feat:`     | a new feature                                           | minor (`0.X.0`)             |
| `fix:`      | a bug fix                                               | patch (`0.0.X`)             |
| `perf:`     | a performance improvement                               | patch (`0.0.X`)             |
| `docs:`     | documentation only                                      | none — changelog entry only |
| `chore:`    | tooling, CI, dependency bumps, etc.                     | none — changelog entry only |
| `refactor:` | code change that neither fixes a bug nor adds a feature | none — changelog entry only |
| `test:`     | adding or correcting tests                              | none — changelog entry only |
| `style:`    | formatting/whitespace only, no code meaning change      | none — changelog entry only |
| `build:`    | changes to the build system or package dependencies     | none — changelog entry only |
| `ci:`       | changes to CI configuration/scripts                     | none — changelog entry only |
| `revert:`   | reverts a previous commit                               | none — changelog entry only |

Example: `fix: correct resource attribute mapping for cloud exporters`

### Breaking Changes

Add `!` after the type (e.g. `feat!:`) in the PR title and a `BREAKING CHANGE:` footer of the PR description as its own paragraph. Ensure there is sufficient details in the BREAKING CHANGE message as this will be picked up by release-please for CHANGELOG.md

### Troubleshooting

**Prepush**

If there are any issues with githooks, set the permissions:

```bash
chmod +x .githooks/pre-push
chmod +x ./scripts/prepush.sh
```

### Azure tooling

For migrating existing infra to terraform have a look at [aztfexport](https://learn.microsoft.com/en-us/azure/developer/terraform/azure-export-for-terraform/export-terraform-overview)
