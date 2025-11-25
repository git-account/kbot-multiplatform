<!-- Auto-generated Copilot instructions for the kbot repository. -->

This repository is a small Go CLI + Telegram bot. The goal is to give AI coding agents the minimal, actionable context to be productive.

Project overview
- **Module path**: `github.com/git-account/kbot-multiplatform` (see `go.mod`).
- **Entry point**: `main.go` calls `cmd.Execute()` (Cobra-based CLI in `cmd/`).
- **Commands**: `cmd/` contains Cobra commands:
  - `cmd/root.go` — root command and `Execute()` function.
  - `cmd/kbot.go` — the Telegram bot subcommand (Use: `kbot`, alias `start`).
  - `cmd/version.go` — `appVersion` variable printed by `version` command and injected at build time.

Build and Docker
- Default local build: `make build`. Important details:
  - `Makefile` computes `VERSION` using Git tags/commit and injects it with `-ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"`.
  - The Makefile sets `CGO_ENABLED=0 GOOS=linux GOARCH=$(dpkg --print-architecture)` so builds are static linux binaries.
+- Docker: `Dockerfile` uses a multi-stage build and accepts the following build-args which let you cross-compile for different OS/architectures:
+  - `TARGETOS` (default: `linux`) — GOOS value to build a binary for
+  - `TARGETARCH` (default: `amd64`) — GOARCH value to build a binary for
+  - `VERSION` (default: `dev`) — used to inject the `appVersion` value in the binary with `-ldflags`
+  - `BASE_IMAGE` (default: `scratch`) — final base image for the runtime stage. Set this to a Windows base (e.g., `mcr.microsoft.com/windows/nanoserver:1809`) when building a Windows image.
+
+  Important notes:
+  - The builder must match `go.mod` `go` version. The repo uses `go 1.24`, so the builder must be `golang:1.24` (or newer). If you change `go.mod`, update the Dockerfile accordingly.
  - Multi-arch images are built by invoking `docker build` per-platform in the `image-all` make target since `docker buildx` is not used by default in this project. Example (image-all):
    - `make image-all` will invoke `docker build` for `linux/amd64` and `linux/arm64` (and a Windows variant on a Windows builder if available).
+  - macOS images are not supported by Docker — for macOS you can cross-compile a darwin binary using `make macos` and ship it as an artifact, but it cannot be packaged into a Docker container.
  - Use `go mod download` (or `go env -w GOPRIVATE=...` as needed) inside the builder to populate the module cache before `make build`.

Runtime / environment
- The Telegram bot requires `TELE_TOKEN` environment variable. The code reads `TELE_TOKEN` from the environment in `cmd/kbot.go` and will fatal if it's missing or invalid.
- To start the bot from the built binary run: `TELE_TOKEN=<token> ./kbot kbot` (or `./kbot start`), since the bot is implemented as a subcommand.

Conventions & patterns
- Version injection: `appVersion` lives in `cmd/version.go` and is intentionally set via `-ldflags -X=...` at build time. When changing the variable name, update the Makefile ldflags accordingly.
- CLI structure: the code uses Cobra; subcommands are added in `init()` functions inside `cmd/*.go` files. Look for `rootCmd.AddCommand(...)` when adding commands.
- Dependencies: `telebot` is used for Telegram interactions (`gopkg.in/telebot.v3`). Follow its async handlers pattern (see `kbot.Handle(...)` in `cmd/kbot.go`).

Developer workflows (quick commands)
- Local build: `make build` -> produces `./kbot`
- Run tests: `make test` (or `go test ./...`)
- Lint/format: `make format` and `make lint` (lint uses `golint` if installed)
- Docker build: `docker build -t kbot .` (ensure Dockerfile builder image matches `go.mod` (`golang:1.24`)). If you see `cannot compile Go 1.24 code` that means the builder image is older than `go.mod` requires.

Areas to be careful about
- The CLI defines a `kbot` subcommand with the same name as the binary; to actually run the bot you must invoke the subcommand (`./kbot kbot`), not just `./kbot` (which shows help). Consider simplifying this if you change UX.
- Makefile runs `dpkg --print-architecture` to determine `GOARCH`. This assumes a Debian-like environment in the build context (the builder image is Debian-based). If switching to distroless/alpine for building, adapt this logic.

Files that are authoritative sources of truth
- `go.mod` — Go version + module path
- `Makefile` — local build flags and version injection
- `Dockerfile` — container build flow and minimal runtime image choices
- `cmd/*.go` — business logic (CLI + bot behavior)

If you need to change the Docker build or the Makefile
- Prefer updating `go.mod` and the Dockerfile together so the builder Go version matches the module Go version.
- Fix ldflags quoting in `Makefile` if you touch version injection; use `-ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"`.

If anything here is unclear or you'd like a different granularity (more examples, CI notes, or debugging commands), tell me which sections to expand.
