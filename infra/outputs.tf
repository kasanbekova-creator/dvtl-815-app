output "ecr_repository_url" {
  description = <<-EOT
    URL of the ECR repository this stack owns. dvtl-815-resources var.app_image must equal this value
    so its Deployment pulls the images GitHub Actions pushes (…dkr.ecr.<region>.amazonaws.com/<name>).
  EOT
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository (the GitHub Actions OIDC role's push permission is scoped to this)."
  value       = aws_ecr_repository.app.arn
}

output "gha_ecr_push_role_arn" {
  description = <<-EOT
    ARN of the GitHub Actions OIDC role. Set this as the `AWS_ROLE_ARN` (or role-to-assume) input of
    the build workflow's aws-actions/configure-aws-credentials step.
  EOT
  value       = aws_iam_role.gha_ecr_push.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the account's GitHub OIDC provider (import this if it already exists in the account)."
  value       = aws_iam_openid_connect_provider.github.arn
}
