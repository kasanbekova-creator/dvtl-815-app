# DVTL-815 — sample app (github-poc / env0 fork)

Tiny Go web server + the CI that builds it into a container, pushes it to **ECR**, and hands the
image tag off to the deploy repo. This is the **build** half; [`dvtl-815-resources`](https://github.com/kasanbekova-creator/dvtl-815-resources)
(deployed by **env0**) is the other half.

```
dvtl-815-app (this repo)                    dvtl-815-resources (env0-deployed)
  src/main.go ──build──▶ ECR:<git-sha>
  Dockerfile                    └─commit app_image_tag──▶ env0 Git trigger fires
  infra/ (owns ECR + OIDC role)                            → plan → apply → EKS rollout
```

> Fork isolation: this fork's ECR repo is **`env0-dvtl815-app`**, distinct from the aws-poc fork's
> `dvtl815-app` in the same account (355433853014). The binary is **`tofu`**, never `terraform`.

## Layout

```
├── Dockerfile              # multi-stage golang:1.22 → distroless/static (nonroot, :8080)
├── src/                    # main.go (GET / + /healthz), main_test.go, go.mod (zero deps)
├── infra/                  # ECR repo + GitHub Actions OIDC role (apply by hand once)
└── .github/workflows/build.yml   # test → build → push :<sha> → commit-back to resources repo
```

## The demo loop

Edit the greeting in `src/main.go` → push to `main` → Actions builds `env0-dvtl815-app:<sha>`,
pushes it, and commits that SHA into `dvtl-815-resources/image_tag.auto.tfvars` → env0 deploys it →
the change is live at `https://env0-dvtl815.355433853014.natera.io` (in-VPC / VPN).

The image tag is the git SHA (ECR is IMMUTABLE), so every deploy is a distinct, traceable version.

## One-time setup

**1. Apply the `infra/` stack** (write-capable AWS profile):
```bash
cd infra
AWS_PROFILE=<write> tofu init && AWS_PROFILE=<write> tofu apply
AWS_PROFILE=<write> tofu output gha_ecr_push_role_arn   # → AWS_ROLE_ARN secret below
```
If apply errors `EntityAlreadyExists` on the GitHub OIDC provider (one per account), import it:
```bash
AWS_PROFILE=<write> aws iam list-open-id-connect-providers   # copy the token.actions... ARN
AWS_PROFILE=<write> tofu import aws_iam_openid_connect_provider.github <arn> && AWS_PROFILE=<write> tofu apply
```

**2. Add repo secrets** (Settings → Secrets and variables → Actions):
| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | the `gha_ecr_push_role_arn` output above |
| `RESOURCES_REPO_TOKEN` | GitHub PAT with **Contents: write** on `dvtl-815-resources` |

**3. Enable env0's Git trigger** on the `dvtl-815-resources` project (env0 UI) — otherwise the
commit-back lands but no deploy fires.

## Local check (no AWS)
```bash
docker build --build-arg APP_VERSION=dev -t dvtl815-app:dev .
docker run --rm -p 8080:8080 dvtl815-app:dev
curl -s localhost:8080/ ; curl -s localhost:8080/healthz
```

## Notes
- `cd src && go test ./...` gates every build — a route regression fails before an image is pushed.
- Auth is split by design: the **OIDC role** pushes images (no git access); the **PAT** does the
  commit-back (no AWS access).
- No-loop: this workflow triggers only on this repo; the commit-back targets the resources repo and
  carries `[skip-app-ci]` under the `dvtl815-app-pipeline` bot identity.
