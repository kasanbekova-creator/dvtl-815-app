# ECR repository for the sample app image — OWNED by this stack (this repo is the thing that pushes
# to it; the deploy repo dvtl-815-resources only references it by name via var.app_image). The image
# tag is always the git SHA.
#
# NAMING / FORK ISOLATION: this repo is `env0-dvtl815-app`, deliberately DISTINCT from the aws-poc
# fork's `dvtl815-app` repo, which already exists in this SAME account (355433853014). The two forks
# share the account but must NOT share a registry — see the `env0-` prefix convention used across the
# github-poc fork (namespaces in dvtl-815-resources, IAM role names in agent/). var.app_image in
# dvtl-815-resources points at THIS repo.
#
# image_tag_mutability = IMMUTABLE enforces the SHA discipline at the registry: a given tag can be
# pushed exactly once, so <repo>:<sha> can never be silently overwritten with different bytes. That
# is the registry-level guarantee behind the deploy repo's tofu-plan diff on app_image_tag.
# force_delete = true so `tofu destroy` can clean up a PoC repo that still holds images.

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # throwaway PoC — allow destroy to remove a non-empty repo

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    "dvtl-815-poc" = "true"
    "purpose"      = "app-image"
    "fork"         = "github-poc"
  }
}

# Keep the registry tidy: expire untagged images (failed/replaced pushes) quickly, and cap the
# number of tagged images retained. PoC hygiene — tune retention before production.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        # tagStatus = "any" means "every image, regardless of tag" — the right primitive for a
        # simple "keep the most recent N" cap. ECR requires an "any" rule to have the HIGHEST
        # rulePriority and be evaluated last, so this stays priority 2, after the untagged rule.
        rulePriority = 2
        description  = "Keep only the most recent 20 images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      },
    ]
  })
}
