# GitHub Actions OIDC role — the principal the build workflow (.github/workflows/build.yml) assumes
# to push to ECR. This REPLACES aws-poc's CodeBuild service role: there is no CodeBuild here, the
# image is built by GitHub Actions, and GitHub authenticates to AWS via OpenID Connect (no static
# keys stored anywhere).
#
# How OIDC works: GitHub mints a short-lived JWT for the workflow run; AWS STS trades it for
# temporary role credentials IF the token's `sub` claim matches the trust policy's condition below.
# The role's only power is push to THIS ECR repo (env0-dvtl815-app) — scoped to that ARN. It does
# NOT commit back to dvtl-815-resources; that hand-off is done by GitHub Actions using a repo secret
# (a PAT / deploy key), not by this AWS role. Keeping the two concerns separate means this AWS role
# never needs cross-repo git permissions.

# The account's GitHub OIDC provider. Created once per account; this stack references it by the
# well-known GitHub issuer URL. If the aws-poc fork or SRE has already created it, import it
# (`tofu import aws_iam_openid_connect_provider.github <arn>`) rather than applying a duplicate —
# an account may hold only ONE provider per URL.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint. AWS now validates GitHub's certificate chain against its own trust
  # store, so this value is no longer security-critical, but the field is still required by the API.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  # NOTE: no `fork` tag here — the provider's default_tags already sets `Fork`, and IAM tag keys are
  # CASE-INSENSITIVE, so `fork` + `Fork` would collide ("Duplicate tag keys found").
  tags = {
    "dvtl-815-poc" = "true"
  }
}

# --- Trust policy: only THIS repo's workflows may assume the role -------------
# The StringLike on `sub` restricts to the github_repo on any branch/ref (repo:owner/name:*).
# Tighten to `repo:${var.github_repo}:ref:refs/heads/main` if you want main-only assumption.
data "aws_iam_policy_document" "gha_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "gha_ecr_push" {
  name               = "${var.name_prefix}-env0-app-gha-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json

  # No `fork` tag — see the OIDC provider above; provider default_tags sets `Fork`, IAM keys are
  # case-insensitive, so a lowercase `fork` collides.
  tags = {
    "dvtl-815-poc" = "true"
  }
}

# --- Permissions: ECR auth + push to THIS repo only --------------------------
# GetAuthorizationToken returns an account-wide token and has NO resource-level scoping — AWS
# requires it to be "*". Every layer/image action is scoped to the app repo ARN.
data "aws_iam_policy_document" "gha_ecr_push" {
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushToAppRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "gha_ecr_push" {
  name   = "${var.name_prefix}-env0-app-gha-ecr-push-policy"
  role   = aws_iam_role.gha_ecr_push.id
  policy = data.aws_iam_policy_document.gha_ecr_push.json
}
