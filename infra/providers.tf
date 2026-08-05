provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "DVTL-815-PoC"
      ManagedBy = "OpenTofu"
      Owner     = "kasanbekova"
      Fork      = "github-poc"
    }
  }
}
