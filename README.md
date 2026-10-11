# two-tier-infra

Infrastructure for the two-tier app: VPC, EKS, ECR, and the IAM roles both pipelines use.
Application code lives in the separate **two-tier-app** repo.

```
bootstrap/   run once locally: state bucket, GitHub OIDC provider, infra CI role
eks/         VPC, EKS, ECR, app deploy role (applied by GitHub Actions)
platform/    cluster-level k8s objects the app team doesn't own (namespace)
.github/workflows/
  terraform.yml   PR -> plan, main/manual -> apply
  destroy.yml     manual, tears everything down
```

## Who can do what

| Pipeline | IAM role | Can do |
|---|---|---|
| infra repo | `two-tier-infra-ci` (from bootstrap) | Create/destroy all infra, cluster admin |
| app repo | `two-tier-eks-app-deploy` (from eks/) | Push to the 2 ECR repos, deploy inside the `two-tier` namespace only |

## One-time setup

**1. Bootstrap (local, your AWS credentials)**

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set github_owner
terraform init && terraform apply
terraform output
```

If the OIDC provider already exists in your account, set `create_github_oidc_provider = false`.
Keep `bootstrap/terraform.tfstate` somewhere safe. It isn't committed.

**2. Point the EKS stack at the state bucket**

- In `eks/backend.hcl`, set `bucket` to the `state_bucket` output.
- In `eks/terraform.tfvars`, set `github_owner`, and add your IAM user ARN to `admin_principal_arns` so you can use kubectl locally. Get it with `aws sts get-caller-identity`. Don't use the root account.

**3. Create the GitHub repo and settings**

In the repo, go to Settings > Environments and create an environment called `infra`. Optionally, add yourself as a required reviewer to get an approval gate before apply and destroy.

Then in Settings > Secrets and variables > Actions:

| Type | Name | Value |
|---|---|---|
| Secret | `AWS_ROLE_ARN` | bootstrap output `infra_ci_role_arn` |
| Variable | `AWS_REGION` | `ap-south-1` |
| Variable | `EKS_CLUSTER` | `two-tier-eks` |

**4. Push**

```bash
git init && git add . && git commit -m "Infra for two-tier app"
git branch -M main
git remote add origin https://github.com/<you>/two-tier-infra.git
git push -u origin main
```

The push to `main` runs `apply`, which takes about 15 minutes. The job summary then shows the values to set in the **app repo**. Set them once: role and repo names are fixed, so they stay the same across every destroy and rebuild.

Do **not** run `terraform apply` in `eks/` from your laptop. The CI role must be the cluster creator, or the destroy workflow loses kubectl access.

## Daily routine

- **Start:** Actions > Terraform > Run workflow (~15 min). Then run the app repo's deploy workflow.
- **Stop:** Actions > Destroy > type `two-tier-eks`. This removes the app's load balancer, destroys everything, and lists any leftovers that still cost money.

The state bucket and IAM roles from bootstrap stay. They cost close to nothing.

## Making changes

Open a PR that touches `eks/`. The plan appears in the job summary. Merge to apply.
