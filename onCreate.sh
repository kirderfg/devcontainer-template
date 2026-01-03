#!/bin/bash
# One-time setup when devcontainer is created
# NOTE: Secrets are injected as environment variables by dp.sh on the VM
# This container does NOT have access to 1Password CLI or tokens
set -e

echo "========================================"
echo "  DevContainer Setup"
echo "========================================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[Setup]${NC} $1"; }
warn() { echo -e "${YELLOW}[Setup]${NC} $1"; }
info() { echo -e "${BLUE}[Setup]${NC} $1"; }

# Save injected secrets to persistent file for shell sessions
# Secrets are passed as env vars by dp.sh (1Password stays on VM)
log "Saving injected secrets for persistent access..."
mkdir -p ~/.config/dev_env
chmod 700 ~/.config/dev_env

# Create secrets file from injected environment variables
cat > ~/.config/dev_env/secrets.sh << EOF
#!/bin/bash
# Secrets injected by dp.sh from 1Password (read on VM, not in container)
# This file is auto-generated - do not edit manually

export GITHUB_TOKEN="${GITHUB_TOKEN:-}"
export GH_TOKEN="${GH_TOKEN:-}"
export ATUIN_USERNAME="${ATUIN_USERNAME:-}"
export ATUIN_PASSWORD="${ATUIN_PASSWORD:-}"
export ATUIN_KEY="${ATUIN_KEY:-}"
export PET_GITHUB_TOKEN="${PET_GITHUB_TOKEN:-}"
EOF
chmod 600 ~/.config/dev_env/secrets.sh

# Create init.sh for shell startup
cat > ~/.config/dev_env/init.sh << 'INITSH'
#!/bin/bash
# Source this in shell startup to load secrets
if [ -f ~/.config/dev_env/secrets.sh ]; then
    source ~/.config/dev_env/secrets.sh
fi
INITSH
chmod +x ~/.config/dev_env/init.sh

# Log what secrets were injected
if [ -n "$GITHUB_TOKEN" ]; then
    log "GitHub token available"
fi
if [ -n "$ATUIN_USERNAME" ]; then
    log "Atuin credentials available"
fi
if [ -n "$PET_GITHUB_TOKEN" ]; then
    log "Pet token available"
fi

# Run shell-bootstrap for terminal tools (zsh, starship, atuin, yazi, glow, etc.)
# SHELL_BOOTSTRAP_NONINTERACTIVE=1 is required for DevPod/CI environments
log "Running shell-bootstrap..."
curl -fsSL https://raw.githubusercontent.com/kirderfg/shell-bootstrap/main/install.sh -o /tmp/shell-bootstrap-install.sh
SHELL_BOOTSTRAP_NONINTERACTIVE=1 bash /tmp/shell-bootstrap-install.sh || warn "shell-bootstrap failed (non-fatal)"
rm -f /tmp/shell-bootstrap-install.sh

# Ensure secrets are loaded in zsh sessions
grep -q "dev_env/init.sh" ~/.zshrc 2>/dev/null || echo "[ -f ~/.config/dev_env/init.sh ] && source ~/.config/dev_env/init.sh" >> ~/.zshrc

# Ensure PATH includes local bins (for atuin, pet, etc.)
export PATH="$HOME/.local/bin:$HOME/.atuin/bin:$PATH"

# Configure Atuin login if credentials available (from injected env vars)
if [ -n "$ATUIN_USERNAME" ] && [ -n "$ATUIN_PASSWORD" ] && [ -n "$ATUIN_KEY" ]; then
    if command -v atuin &> /dev/null; then
        log "Logging into Atuin..."
        atuin login -u "$ATUIN_USERNAME" -p "$ATUIN_PASSWORD" -k "$ATUIN_KEY" 2>/dev/null && log "Atuin logged in" || warn "Atuin login failed"
        atuin sync 2>/dev/null || true
    fi
fi

# Configure Pet snippets if token available
if [ -n "$PET_GITHUB_TOKEN" ]; then
    if command -v pet &> /dev/null; then
        log "Configuring Pet snippets..."
        mkdir -p ~/.config/pet
        cat > ~/.config/pet/config.toml << PETCONFIG
[General]
  snippetfile = "$HOME/.config/pet/snippet.toml"
  editor = "vim"
  column = 40
  selectcmd = "fzf"
  backend = "gist"
  sortby = "recency"

[Gist]
  file_name = "pet-snippet.toml"
  access_token = "$PET_GITHUB_TOKEN"
  gist_id = ""
  public = false
  auto_sync = true
PETCONFIG
        pet sync 2>/dev/null && log "Pet snippets synced" || warn "Pet sync failed"
    fi
fi

# Install security scanning tools
log "Installing security tools..."
pip install --quiet safety bandit

# Install gitleaks for secret detection
if ! command -v gitleaks &> /dev/null; then
    log "Installing gitleaks..."
    curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz | tar -xz -C /tmp
    sudo mv /tmp/gitleaks /usr/local/bin/
fi

# Install trivy for vulnerability scanning
if ! command -v trivy &> /dev/null; then
    log "Installing trivy..."
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
fi

# Install Snyk CLI
if ! command -v snyk &> /dev/null; then
    log "Installing Snyk CLI..."
    npm install -g snyk
    warn "Run 'snyk auth' to authenticate with Snyk"
fi

# Install Claude Code UI for web/mobile access (Claude Code CLI is installed by shell-bootstrap)
if ! command -v claude-code-ui &> /dev/null; then
    log "Installing Claude Code UI and PM2..."
    npm install -g @siteboon/claude-code-ui pm2
fi

# Install Task Master for AI task management
if ! command -v task-master &> /dev/null; then
    log "Installing Task Master..."
    npm install -g task-master-ai
fi

# Configure Task Master MCP for Claude Code
log "Configuring Task Master MCP..."
mkdir -p ~/.claude
if [ ! -f ~/.claude/.mcp.json ]; then
    cat > ~/.claude/.mcp.json << 'MCPJSON'
{
  "mcpServers": {
    "taskmaster-ai": {
      "command": "npx",
      "args": ["-y", "--package=task-master-ai", "task-master-ai"]
    }
  }
}
MCPJSON
    log "Task Master MCP config created"
fi

# Install Tailscale for remote SSH access
if ! command -v tailscale &> /dev/null; then
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Configure Tailscale if auth key available (from injected env var)
if [ -n "$TAILSCALE_AUTH_KEY" ]; then
    log "Configuring Tailscale..."
    # Start tailscaled in userspace mode (works in containers without root)
    sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock > /tmp/tailscaled.log 2>&1 &
    sleep 2

    # Get container/workspace name for hostname
    CONTAINER_NAME="${DEVCONTAINER_NAME:-$(basename $(pwd))}"
    TS_HOSTNAME="devpod-${CONTAINER_NAME}"

    # Remove existing Tailscale devices matching this hostname (if API key available)
    if [ -n "$TAILSCALE_API_KEY" ]; then
        log "Checking for existing Tailscale devices matching: $TS_HOSTNAME..."
        EXISTING_DEVICES=$(curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
            "https://api.tailscale.com/api/v2/tailnet/-/devices" 2>/dev/null | \
            jq -r --arg hostname "$TS_HOSTNAME" \
            '.devices[] | select(.name | startswith($hostname)) | "\(.id)|\(.name)"' 2>/dev/null)

        if [ -n "$EXISTING_DEVICES" ]; then
            echo "$EXISTING_DEVICES" | while IFS='|' read -r device_id device_name; do
                if [ -n "$device_id" ]; then
                    log "Removing existing device: $device_name ($device_id)..."
                    curl -s -X DELETE -H "Authorization: Bearer $TAILSCALE_API_KEY" \
                        "https://api.tailscale.com/api/v2/device/$device_id" 2>/dev/null && \
                        log "Removed: $device_name" || warn "Failed to remove: $device_name"
                fi
            done
            sleep 2
        else
            log "No existing devices found"
        fi
    fi

    # Connect to Tailscale (auth key may be tagged for receive-only access)
    sudo tailscale up --authkey="$TAILSCALE_AUTH_KEY" --ssh --hostname="$TS_HOSTNAME" --force-reauth && log "Tailscale connected!" || warn "Tailscale auth failed"

    if tailscale status &> /dev/null; then
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "pending")
        log "Tailscale IP: $TS_IP"
        info "NOTE: This devpod can receive SSH but cannot initiate tailnet connections (security)"
    fi

    # Clean up Tailscale auth key from environment (security)
    unset TAILSCALE_AUTH_KEY
    unset TAILSCALE_API_KEY
    # Remove from secrets file too
    sed -i '/TAILSCALE_/d' ~/.config/dev_env/secrets.sh 2>/dev/null || true
    log "Tailscale keys removed from environment (used once)"
else
    warn "Tailscale not configured (no auth key injected)"
fi

# Install Python dependencies if pyproject.toml exists
if [ -f "pyproject.toml" ]; then
    log "Installing Python dependencies..."
    pip install --upgrade pip
    pip install -e ".[dev]" 2>/dev/null || pip install -e "." 2>/dev/null || true
fi

# Install Node dependencies if package.json exists
if [ -f "package.json" ]; then
    log "Installing Node dependencies..."
    npm install
fi

# Setup pre-commit hooks
if [ -f ".pre-commit-config.yaml" ]; then
    log "Installing pre-commit hooks..."
    pre-commit install
    pre-commit install --hook-type commit-msg 2>/dev/null || true
fi

# Configure git
log "Configuring git..."
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global fetch.prune true
git config --global credential.helper '!gh auth git-credential'

# Setup gh CLI with token if available (from injected env var)
if [ -n "$GITHUB_TOKEN" ]; then
    if command -v gh &> /dev/null; then
        log "Configuring GitHub CLI..."
        echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null && log "GitHub CLI authenticated" || warn "GitHub CLI auth failed"
        gh auth setup-git 2>/dev/null || true
    fi
else
    if command -v gh &> /dev/null; then
        if ! gh auth status &> /dev/null; then
            warn "GitHub CLI not authenticated (no token injected)"
        fi
    fi
fi

log "Setup complete!"
info "Security: 1Password CLI is NOT available in this container"
echo ""
