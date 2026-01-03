# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Security Model

**This container uses a zero-trust secret management approach:**

- **1Password CLI is NOT installed** in containers
- Secrets are read from 1Password on the VM by `dp.sh` and injected as environment variables
- Tailscale is configured for **receive-only** access (can accept SSH, cannot initiate tailnet connections)
- Claude credentials are copied from the VM for seamless authentication

This isolation ensures safe, unattended Claude Code execution.

## Project Overview

Devcontainer-template is a reusable devcontainer configuration for Python + Node projects. It's designed to be used as a **git submodule** at `.devcontainer/` in other projects.

## Usage

This template is added to projects as a submodule:
```bash
git submodule add https://github.com/kirderfg/devcontainer-template.git .devcontainer
```

## Files

| File | Purpose |
|------|---------|
| `devcontainer.json` | Container configuration (image, features, extensions, settings) |
| `onCreate.sh` | One-time setup - configures secrets from env vars, installs tools |
| `postStart.sh` | Runs every time container starts |
| `.pre-commit-config.yaml` | Git hooks configuration (copy to project root) |
| `security-scan.sh` | Manual security scanning script |

## What Gets Installed

### Via devcontainer.json features:
- Python 3.12 (base image: `mcr.microsoft.com/devcontainers/python:1-3.12-bookworm`)
- Node.js 20
- Docker-in-Docker with Compose v2
- GitHub CLI
- Pre-commit framework

### Via onCreate.sh:
- **shell-bootstrap** - Full terminal environment (zsh, starship, atuin, yazi, pet, etc.)
- **Security tools** - gitleaks, trivy, snyk, safety, bandit
- **Claude Code UI** - Web interface (port 3001) managed by PM2
- **Task Master** - AI task management via MCP
- **Tailscale** - Remote SSH access (receive-only)

### Via postStart.sh:
- Docker daemon startup
- Docker Compose services (if configured)
- Tailscale daemon
- Claude Code UI (PM2)

## Secret Injection

Secrets are injected by `dp.sh` on the VM as environment variables:

| Variable | Source | Purpose |
|----------|--------|---------|
| `GITHUB_TOKEN` | `op://DEV_CLI/GitHub/PAT` | Git auth, gh CLI |
| `GH_TOKEN` | Same as above | Alias |
| `ATUIN_USERNAME` | `op://DEV_CLI/Atuin/username` | Shell history sync |
| `ATUIN_PASSWORD` | `op://DEV_CLI/Atuin/password` | Shell history sync |
| `ATUIN_KEY` | `op://DEV_CLI/Atuin/key` | Shell history encryption |
| `PET_GITHUB_TOKEN` | `op://DEV_CLI/Pet/PAT` | Pet snippet sync |
| `TAILSCALE_AUTH_KEY` | `op://DEV_CLI/Tailscale/devpod_auth_key` | Device registration |
| `TAILSCALE_API_KEY` | `op://DEV_CLI/Tailscale/api_key` | Remove old devices |

**Note:** Tailscale keys are used once and then removed from the environment.

## Network Access

- **Public Internet**: Full access (npm, pip, git clone, etc.)
- **Tailscale SSH**: Can receive incoming connections
- **Tailscale Outbound**: BLOCKED (cannot reach other tailnet devices)

DevPods use `tag:devpod` which has no outbound permissions in the Tailscale ACL.

## Users

- Container runs as `vscode` user (uid 1000)
- Tailscale SSH logs in as `root` - use `su - vscode` for shell-bootstrap tools
- shell-bootstrap installs to `/home/vscode/`

## Modifying the Template

When changing files:

### devcontainer.json
- Add features to `features` section
- Add VS Code extensions to `customizations.vscode.extensions`
- Add ports to `forwardPorts` (though Tailscale is preferred)

### onCreate.sh
- Secrets are already available as environment variables
- Do NOT use `op read` - 1Password CLI is not installed
- Use `log()` and `warn()` for consistent output

### postStart.sh
- Add services that need to start on every container start
- Check for command existence before running

## Common Issues

**`op` command not found:**
This is expected. 1Password CLI is intentionally NOT installed for security.

**gh not authenticated:**
Check if `GITHUB_TOKEN` was injected: `echo $GITHUB_TOKEN`

**shell-bootstrap tools not working:**
You're likely logged in as root. Run `su - vscode` then `dev`.

**Claude Code UI not accessible:**
Check `pm2 status` and `pm2 logs claude-code-ui`.

**Tailscale not connected:**
Auth key may not have been injected. Rebuild the devpod with `dp.sh rebuild`.
