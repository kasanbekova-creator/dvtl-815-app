terraform {
  backend "s3" {
    bucket         = "natera-dvtl815-github-poc-state"
    key            = "app/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "dvtl815-github-poc-locks"
    encrypt        = true

    # Same dedicated github-poc bucket + lock table as the resources root (../dvtl-815-resources
    # backend.tf, key resources/*) and the agent stack (key agent/*), with a DISTINCT key
    # (app/terraform.tfstate) so this app-infra stack has its own independent state. Deliberately NOT
    # the aws-poc fork's shared `natera-dvtl815-poc-state` / `dvtl815-poc-locks`.
  }
}
