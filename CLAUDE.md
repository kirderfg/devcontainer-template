# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
| `onCreate.sh` | One-time setup when container is created |
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
- **1Password CLI** - Secrets management (installed by shell-bootstrap)
- **Security tools** - gitleaks, trivy, snyk, safety, bandit
- **Claude Code UI** - Web interface (port 3001) managed by PM2
- **Tailscale** - Remote SSH access to container

### Via postStart.sh:
- Docker daemon startup
- Docker Compose services (if configured)
- Tailscale daemon
- Claude Code UI (PM2)

## 1Password Secrets Required

Secrets are loaded from the `DEV_CLI` vault via `OP_SERVICE_ACCOUNT_TOKEN`:

| Secret | Purpose |
|--------|---------|
| `op://DEV_CLI/GitHub/PAT` | GitHub CLI authentication, git credentials |
| `op://DEV_CLI/Tailscale/auth_key` | Tailscale device registration |
| `op://DEV_CLI/Tailscale/api_key` | Auto-remove old Tailscale devices |
| `op://DEV_CLI/Atuin/username,password,key` | Shell history sync |

## Key Environment Variables

| Variable | Purpose |
|----------|---------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account (passed via `--workspace-env`) |
| `SHELL_BOOTSTRAP_NONINTERACTIVE` | Set to `1` for unattended setup |
| `DEVCONTAINER_NAME` | Used for Tailscale hostname (`devpod-<name>`) |

## Tailscale Networking

- Containers get Tailscale SSH access at hostname `devpod-<workspace-name>`
- Old devices with same hostname are auto-removed on redeploy (requires API key)
- Access via: `ssh root@devpod-<workspace-name>`, then `su - vscode` for full shell

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
- Add new tools after shell-bootstrap runs
- Add new 1Password secrets to the secrets loading section
- Use `log()` and `warn()` for consistent output

### postStart.sh
- Add services that need to start on every container start
- Check for command existence before running

## Common Issues

**Tailscale device already exists:**
The API key (`op://DEV_CLI/Tailscale/api_key`) must be set for auto-cleanup.

**shell-bootstrap tools not working:**
You're likely logged in as root. Run `su - vscode` then `dev`.

**Claude Code UI not accessible:**
Check `pm2 status` and `pm2 logs claude-code-ui`.
