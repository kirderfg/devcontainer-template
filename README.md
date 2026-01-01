# DevContainer Template

A reusable devcontainer configuration for Python + Node projects with security scanning, pre-commit hooks, and modern tooling. Designed to be used as a **git submodule**.

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

### Security Tools
- **Gitleaks** - Secret detection in commits
- **Trivy** - Container/dependency vulnerability scanning
- **Bandit** - Python security linter
- **Safety** - Python dependency vulnerability checker
- **Snyk CLI** - Dependency & container scanning

### Networking
- **Tailscale** - SSH access to container (hostname: `devpod-<workspace>`)

## Files

| File | Purpose |
|------|---------|
| `devcontainer.json` | Container configuration |
| `onCreate.sh` | One-time setup (installs tools, dependencies) |
| `postStart.sh` | Runs on every container start |
| `.pre-commit-config.yaml` | Git hooks configuration (copy to project root) |
| `security-scan.sh` | Manual security scanning |

## 1Password Integration

Secrets are loaded from 1Password `DEV_CLI` vault. Pass the token when creating workspaces:

```bash
devpod up github.com/your/repo \
  --workspace-env OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/dev_env/op_token) \
  --workspace-env SHELL_BOOTSTRAP_NONINTERACTIVE=1
```

### Required 1Password Items

| Item | Field | Purpose |
|------|-------|---------|
| `GitHub` | `PAT` | GitHub CLI + git credentials |
| `Tailscale` | `auth_key` | Device registration |
| `Tailscale` | `api_key` | Auto-remove old devices on redeploy |
| `Atuin` | `username`, `password`, `key` | Shell history sync |

## Tailscale Access

Each container gets a Tailscale IP. Connect directly from anywhere:

```bash
# SSH into container (as root)
ssh root@devpod-myproject

# Switch to vscode user for full shell environment
su - vscode
dev  # Launch tmux dev session
```

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

## Customization

### Add Python Dependencies

Edit `pyproject.toml` in your project:
```toml
[project.optional-dependencies]
dev = ["pytest", "black", "ruff"]
```

### Add VS Code Extensions

Edit `devcontainer.json`:
```json
"customizations": {
  "vscode": {
    "extensions": ["your.extension-id"]
  }
}
```

## Troubleshooting

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

### Tailscale device already exists
Ensure `api_key` is set in 1Password for auto-cleanup.

### Claude Code UI not accessible
```bash
pm2 status claude-code-ui
pm2 logs claude-code-ui
pm2 restart claude-code-ui
```
