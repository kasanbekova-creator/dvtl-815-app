# Multi-stage build for the DVTL-815 sample app.
#
# Stage 1 compiles a static binary with the git SHA baked in via -ldflags. Stage 2 is
# gcr.io/distroless/static — no shell, no package manager, runs as nonroot — so the final image is
# tiny (~a few MB over the binary) and has minimal attack surface.
#
# The build arg APP_VERSION is passed by .github/workflows/build.yml as the git commit SHA
# (${{ github.sha }}); locally it defaults to "dev". That value becomes main.version.

# --- Stage 1: build ----------------------------------------------------------
FROM golang:1.22 AS build
WORKDIR /src

# The app has no third-party dependencies, so copying go.mod is enough for module mode; there is no
# go.sum to copy and nothing to download. (If deps are ever added, add `COPY go.sum .` + `go mod download`.)
COPY src/go.mod .
COPY src/main.go .

ARG APP_VERSION=dev
# CGO off + explicit linux/amd64 => a fully static binary that runs on distroless/static.
# -ldflags "-X main.version=..." injects the version; -s -w strips debug info to shrink the binary.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags "-s -w -X main.version=${APP_VERSION}" -o /out/app .

# --- Stage 2: runtime --------------------------------------------------------
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=build /out/app /app

# Documents the listen port (8080, non-root). The Deployment sets containerPort to match (app.tf).
EXPOSE 8080

# nonroot user is provided by the distroless base image (uid 65532).
USER nonroot:nonroot

ENTRYPOINT ["/app"]
