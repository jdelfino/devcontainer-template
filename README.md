# DevContainer Project Template

A Copier template for bootstrapping development projects with:
- DevContainer configuration (Node, Python, Go, Java, or Universal)
- 1Password secrets integration
- Claude Code configuration and skills
- Beads (`bd`) issue tracking

## Quick Start

### Create a New Project

```bash
# Install copier if you haven't
pip install copier

# Create new project from this template
copier copy gh:jdelfino/devcontainer-template my-new-project

# Or from a local clone
copier copy /path/to/devcontainer-template my-new-project
```

You'll be prompted for:
- **project_name**: Your project name (lowercase, hyphens ok)
- **project_description**: Optional one-liner
- **base_container**: Node, Python, Go, Java, or Universal
- **additional_languages**: Extra languages to install
- **op_vault**: Your 1Password vault name

### Update an Existing Project

When the template improves, pull updates into your project:

```bash
cd my-project
copier update
```

Copier shows a diff and lets you selectively accept changes.

## Prerequisites

### 1Password Setup

The template uses 1Password for credential management. This requires a one-time setup.

#### Step 1: Create a Service Account

1. Go to [1password.com](https://my.1password.com) → **Developer Tools** → **Service Accounts**
2. Click **New Service Account**
3. Name it something like `devcontainer`
4. Grant it access to the vault you'll use for development secrets
5. Copy the token (starts with `ops_...`) - you won't see it again

#### Step 2: Set Environment Variables

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
export OP_VAULT="your-vault-name"  # e.g., "myproject-dev"
```

For DevPod, pass them when starting:

```bash
devpod up github.com/user/repo \
  --workspace-env OP_SERVICE_ACCOUNT_TOKEN=$OP_SERVICE_ACCOUNT_TOKEN \
  --workspace-env OP_VAULT=$OP_VAULT
```

#### Step 3: Create Required Vault Items

In your 1Password vault, create these items:

1. **SSH Key** (type: SSH Key)
   - Add your private key
   - Add the tag `devcontainer` (used to find it automatically)

2. **git-config** (type: Secure Note)
   - Add field `name`: Your full name for git commits
   - Add field `email`: Your email for git commits

3. **github-pat** (type: Login or Secure Note)
   - Add field `credential`: A GitHub Personal Access Token
   - Token needs `repo` scope (create at github.com → Settings → Developer settings → Personal access tokens)

#### Vault Naming Convention

The template defaults the vault name to `<project_name>-dev`. You can:
- Use one vault per project (recommended for team projects)
- Use a shared `Development` vault for personal projects

### DevPod / VS Code

Works with DevPod CLI or VS Code Dev Containers extension.

```bash
# DevPod
devpod up my-project

# VS Code
code my-project  # then "Reopen in Container"
```

## What's Included

### DevContainer
- Debian Trixie base with language features
- GitHub CLI (`gh`)
- 1Password CLI (`op`)
- Claude Code
- Beads (`bd`)

### Claude Skills
- **coordinator**: Orchestrate multi-task work with worktrees
- **implementer**: Test-first development for subagents
- **reviewer**: Code review workflow
- **task-completer**: Direct task completion

### Commands
- `/work <id>`: Coordinated workflow for epics/complex tasks
- `/task <id>`: Direct implementation for simple tasks

### Issue Tracking
- Beads (`bd`) pre-configured
- AGENTS.md with workflow documentation
- Git hooks installed automatically

## Adding Project Secrets

1. Add 1Password references to `.env.1password`:
   ```
   API_KEY=op://${OP_VAULT}/my-api/key
   DATABASE_URL=op://${OP_VAULT}/database/url
   ```

2. Rebuild the container (or run `.devcontainer/setup-secrets.sh`)

3. Secrets appear in `.env.local`

## Customization

After scaffolding, customize:

- **Test commands**: Update skills to use your test runner
- **Lint commands**: Add your linter to quality gates
- **Permissions**: Add tool permissions to `.claude/settings.json`
- **Dependencies**: Modify `onCreateCommand` in `devcontainer.json`

## Template Structure

```
template/
├── .devcontainer/
│   ├── devcontainer.json.jinja   # Container config
│   ├── setup.sh                  # 1Password credential setup
│   ├── setup-secrets.sh.jinja    # Project secrets injection
│   └── install-1password-cli.sh  # 1Password CLI installation
├── .claude/
│   ├── settings.json             # Claude permissions
│   ├── skills/                   # Agent skills
│   └── commands/                 # Slash commands
├── .beads/
│   └── config.yaml               # Issue tracking config
├── AGENTS.md.jinja               # Workflow documentation
├── .gitignore.jinja
├── .env.example
└── .env.1password
```
