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

The template uses 1Password for credential management. You need:

1. **Service Account Token**: Set `OP_SERVICE_ACCOUNT_TOKEN` env var
2. **Vault Name**: Set `OP_VAULT` env var (or answer the prompt)
3. **Required Items** in your vault:
   - **SSH Key** tagged `devcontainer` - your SSH private key
   - **Secure Note** named `git-config` with fields:
     - `name`: Your git name
     - `email`: Your git email
   - **Item** named `github-pat` with field:
     - `credential`: A GitHub Personal Access Token

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
- Base container for your chosen language
- Docker-in-Docker
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
