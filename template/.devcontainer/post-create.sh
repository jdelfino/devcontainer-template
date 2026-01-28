#!/bin/bash
# post-create.sh - Install tools and configure the development environment
# Runs via postCreateCommand (after container creation)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

{% if use_1password -%}
# Install 1Password CLI
"$SCRIPT_DIR/install-1password-cli.sh"

{% endif -%}
# Install beads and git hooks
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
bd hooks install 2>/dev/null || true

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# TODO: Add project-specific tool installation here
# Examples:
#   go install github.com/air-verse/air@latest
#   pip install -r requirements.txt
#   npm install

{% if use_1password -%}
# Configure 1Password vault access
"$SCRIPT_DIR/setup.sh"
{% endif -%}
