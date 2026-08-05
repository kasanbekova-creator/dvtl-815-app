terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# This stack provisions only AWS resources (ECR + the GitHub Actions OIDC role/provider) for the app
# build path. No kubernetes/helm providers — it never touches the cluster; it only owns the registry
# and the identity GitHub Actions uses to push to it. The deploy (cluster rollout) is env0's job,
# driven by the commit-back into dvtl-815-resources.
