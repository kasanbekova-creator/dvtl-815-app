# Inputs for the app-infra stack (ECR repo + GitHub Actions OIDC role). Every variable has a default
# so the stack can be applied with a bare `tofu apply`; override any of them with -var or a
# *.tfvars file.

variable "name_prefix" {
  description = "Prefix applied to resource names in this PoC (matches the other github-poc stacks)."
  type        = string
  default     = "dvtl815"
}

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-2"
}

variable "account_id" {
  description = "AWS account ID (shared with the aws-poc fork), used for ARNs / cross-checking."
  type        = string
  default     = "355433853014"
}

variable "ecr_repo_name" {
  description = <<-EOT
    Name of the ECR repository this stack creates and pushes app images to. Deliberately
    `env0-dvtl815-app` — DISTINCT from the aws-poc fork's pre-existing `dvtl815-app` repo in the
    same account, for fork isolation. dvtl-815-resources var.app_image must point at THIS repo.
  EOT
  type        = string
  default     = "env0-dvtl815-app"
}

variable "github_repo" {
  description = <<-EOT
    Immutable subject-claim identifier of the GitHub repo whose Actions workflow may assume the
    ECR-push role via OIDC. The trust policy restricts sts:AssumeRoleWithWebIdentity to `repo:<this>:*`.

    FORMAT — this MUST be the immutable form `<owner>@<owner_id>/<repo>@<repo_id>`, NOT the plain
    `owner/name`. Repos created or renamed after 2026-07-15 use IMMUTABLE subject claims, so the OIDC
    token GitHub actually mints has a `sub` like
    `repo:kasanbekova-creator@294626794/dvtl-815-app@1324372229:ref:refs/heads/main`. The legacy
    `repo:owner/name:*` matcher will NOT match it and STS rejects with "Not authorized to perform
    sts:AssumeRoleWithWebIdentity". Do NOT "simplify" this back to `owner/name`.

    Get the numeric IDs from: `gh api repos/<owner>/<name> --jq '{owner_id:.owner.id, repo_id:.id}'`
    (or GitHub Settings -> Actions -> OIDC configuration -> "Default subject claim prefix"). The IDs
    are stable across renames but change if the repo is recreated.
  EOT
  type        = string
  default     = "kasanbekova-creator@294626794/dvtl-815-app@1324372229"
}
