# DevContainer Template

A reusable devcontainer configuration for Python + Node projects with security scanning, pre-commit hooks, and modern tooling. Designed to be used as a **git submodule**.

## Security Model

**1Password stays on the VM only.** Secrets are:
1. Read from 1Password on the VM by `dp.sh`
2. Injected as environment variables when creating the devpod
3. Never exposed via `op` CLI in containers (it's not installed)

**Tailscale is receive-only.** DevPods:
- Can receive SSH connections from your tailnet
- Cannot initiate outbound connections to other tailnet devices
- Can access the public internet normally

This isolation ensures safe, unattended Claude Code execution.

## Quick Start

### Add to Your Project

```bash
cd your-project
git submodule add https://github.com/kirderfg/devcontainer-template.git .devcontainer
cp .devcontainer/.pre-commit-config.yaml .
git add .devcontainer .pre-commit-config.yaml .gitmodules
git commit -m "Add devcontainer template"
```

### Update the Template

```bash
git submodule update --remote .devcontainer
git add .devcontainer
git commit -m "Update devcontainer template"
```

### Open in DevPod

```bash
# From VM (SSH to dev-vm first)
~/dev_env/scripts/dp.sh up https://github.com/your/repo
```

The `dp.sh` script automatically:
- Reads secrets from 1Password on the VM
- Injects them as environment variables
- Copies Claude credentials for seamless auth
- Creates the devpod with security isolation

## What's Included

### Base Stack
- **Python 3.12** (Debian Bookworm)
- **Node.js 20**
- **Docker-in-Docker** with Compose v2

### Developer Tools (via shell-bootstrap)
- Zsh with vi-mode, Starship prompt
- Atuin (shell history sync)
- Yazi (file manager), Glow (markdown)
- Pet (snippets), Zoxide (smart cd)
- GitHub CLI (`gh`), Delta (git diff)

### AI Coding Assistant
- **Claude Code CLI** - AI assistant in terminal (`claude` command)
- **Claude Code UI** - Web interface on port 3001 (access via Tailscale)
- **Task Master** - AI task management via MCP

### Security Tools
- **Gitleaks** - Secret detection in commits
- **Trivy** - Container/dependency vulnerability scanning
- **Bandit** - Python security linter
- **Safety** - Python dependency vulnerability checker
- **Snyk CLI** - Dependency & container scanning

### Networking
- **Tailscale** - SSH access to container (hostname: `devpod-<workspace>`)
- **Receive-only mode** - Cannot initiate tailnet connections (security)

## Files

| File | Purpose |
|------|---------|
| `devcontainer.json` | Container configuration |
| `onCreate.sh` | One-time setup (installs tools, configures secrets) |
| `postStart.sh` | Runs on every container start |
| `.pre-commit-config.yaml` | Git hooks configuration (copy to project root) |
| `security-scan.sh` | Manual security scanning |
| `CLAUDE.md` | Claude Code instructions |

## Secret Injection

Secrets are injected as environment variables by `dp.sh`:

| Variable | Source | Purpose |
|----------|--------|---------|
| `GITHUB_TOKEN` | `op://DEV_CLI/GitHub/PAT` | Git auth, gh CLI |
| `GH_TOKEN` | Same as above | Alias for GITHUB_TOKEN |
| `ATUIN_USERNAME` | `op://DEV_CLI/Atuin/username` | Shell history sync |
| `ATUIN_PASSWORD` | `op://DEV_CLI/Atuin/password` | Shell history sync |
| `ATUIN_KEY` | `op://DEV_CLI/Atuin/key` | Shell history encryption |
| `PET_GITHUB_TOKEN` | `op://DEV_CLI/Pet/PAT` | Pet snippet sync |
| `TAILSCALE_AUTH_KEY` | `op://DEV_CLI/Tailscale/devpod_auth_key` | Device registration (ephemeral) |
| `TAILSCALE_API_KEY` | `op://DEV_CLI/Tailscale/api_key` | Remove old devices |

**Note:** Tailscale keys are used once during setup and then removed from the environment.

## Tailscale Access

Each container gets a Tailscale IP. Connect from anywhere on your tailnet:

```bash
# SSH into container (as root)
ssh root@devpod-myproject

# Switch to vscode user for full shell environment
su - vscode
dev  # Launch tmux dev session
```

### Receive-Only Security

DevPods use a tagged Tailscale auth key (`tag:devpod`) with ACL rules that:
- Allow incoming SSH from trusted devices
- Block outbound connections to other tailnet devices
- Allow normal internet access

This means even if Claude runs uncontrolled, it cannot reach your VM or other machines.

## Pre-commit Hooks

Hooks run automatically on `git commit`:

| Hook | What it does |
|------|--------------|
| `trailing-whitespace` | Removes trailing spaces |
| `gitleaks` | Blocks commits with secrets |
| `black` | Formats Python code |
| `ruff` | Lints Python (fast) |
| `mypy` | Type checks Python |
| `bandit` | Security checks Python |
| `eslint` | Lints JavaScript |
| `prettier` | Formats JS/JSON/YAML/MD |
| `hadolint` | Lints Dockerfiles |
| `commitizen` | Enforces commit message format |

### Commands

```bash
# Run all hooks on all files
pre-commit run --all-files

# Update hooks to latest versions
pre-commit autoupdate

# Skip hooks (not recommended)
git commit --no-verify -m "message"
```

## Security Scanning

### Automatic (via pre-commit)
Every commit is checked for secrets and security issues.

### Manual Scanning

```bash
# Quick scan (secrets + dependencies)
.devcontainer/security-scan.sh

# Full scan (includes container analysis)
.devcontainer/security-scan.sh full
```

## Claude Code

### CLI Usage

```bash
# Start interactive session
claude

# Ask a question
claude "explain this code" < file.py

# Code review
claude "review this diff" < <(git diff)
```

### Web UI (Port 3001)

Claude Code UI starts automatically via PM2:

```bash
# Check status
pm2 status claude-code-ui

# View logs
pm2 logs claude-code-ui

# Restart if needed
pm2 restart claude-code-ui
```

Access via Tailscale IP: `http://[tailscale-ip]:3001`

## Troubleshooting

### `op` command not found
**This is expected.** 1Password CLI is intentionally NOT installed for security. Secrets are pre-injected as environment variables.

### gh not authenticated
Check if token was injected:
```bash
echo $GITHUB_TOKEN
gh auth status
```

### Docker not working
Wait for Docker daemon to start, or check:
```bash
docker info
```

### `dev` alias not found
You're logged in as root. Switch to vscode user:
```bash
su - vscode
dev
```

### Tailscale not connected
Check if auth key was injected during creation. If not, you'll need to rebuild the devpod:
```bash
# From VM
~/dev_env/scripts/dp.sh rebuild myworkspace
```

### Claude Code UI not accessible
```bash
pm2 status claude-code-ui
pm2 logs claude-code-ui
pm2 restart claude-code-ui
```
