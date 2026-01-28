# DevContainer Project Template

A [Copier](https://copier.readthedocs.io/) template that gives you a fully configured development environment with AI-assisted workflows out of the box. Open your project in a devcontainer and start building — credentials, tooling, and AI agent workflows are all pre-configured.

**What you get:**
- A devcontainer (Node, Python, Go, Java, Rust, or Universal) with [Claude Code](https://claude.ai/code) and [Beads](https://github.com/steveyegge/beads) pre-installed
- 1Password integration for secrets (SSH keys, Git identity, GitHub PAT, project secrets)
- AI agent workflows for planning (`/plan`), coordinated work (`/work`), and quick tasks (`/task`)
- Issue tracking with Beads (`bd`) — dependency-aware, git-friendly, designed for AI agents

## Just Want the Claude Config?

If you already have a development environment and just want the AI agent workflows, copy these directories into your project:

```
.claude/           # Settings, slash commands, and agent skills
.beads/            # Issue tracking config
CLAUDE.md          # Project context for Claude (fill in per-project)
AGENTS.md          # Workflow documentation
```

You can grab them directly from the [`template/`](template/) directory in this repo. You'll also need [Claude Code](https://claude.ai/code) and [Beads](https://github.com/steveyegge/beads) installed.

Then use `/plan`, `/work`, and `/task` in Claude Code to start working. See [AI Agent Workflows](#ai-agent-workflows) below for details.

## Full Template Quick Start

### 1. Create a New Project

```bash
pip install copier
copier copy gh:jdelfino/devcontainer-template my-new-project
```

You'll be prompted for:
- **project_name**: Your project name (lowercase, hyphens ok)
- **project_description**: Optional one-liner
- **base_container**: Node, Python, Go, Java, or Universal
- **additional languages**: Extra language runtimes to install (Python, Node, Go, Java, Rust)
- **use_1password**: Whether to enable 1Password secrets integration
- **op_vault**: Your 1Password vault name (if enabled)

### 2. Open in a DevContainer

```bash
# VS Code
code my-new-project  # then "Reopen in Container"

# DevPod
devpod up my-new-project
```

The container will install all tools and configure credentials automatically on first launch.

### 3. Start Working

```bash
# Plan a new feature
/plan "Add user authentication"

# Work on an existing epic
/work bd-42

# Quick fix
/task bd-7
```

### Updating Your Project

When the template improves, pull updates:

```bash
cd my-project
copier update
```

Copier shows a diff and lets you selectively accept changes.

## Prerequisites

### Host Dependencies

These tools must be installed on your **host machine** (not inside the container):

| Tool | Required? | Install |
|------|-----------|---------|
| [Copier](https://copier.readthedocs.io/) | Yes | `pip install copier` |
| [Docker](https://www.docker.com/) or [DevPod](https://devpod.sh/) | Yes | For running devcontainers |
| [1Password CLI (`op`)](https://1password.com/downloads/command-line/) | If using 1Password | `brew install 1password-cli` or [other methods](https://developer.1password.com/docs/cli/get-started/) |

SSH keys, git identity, and GitHub CLI auth are forwarded automatically from your host by VS Code and DevPod. Everything else (Claude Code, Beads, language runtimes, etc.) is installed inside the container.

### 1Password Setup (Optional)

The template can use 1Password for credential management. Skip this if you chose `use_1password: false`.

1Password is used for **project secrets** (API keys, database URLs, etc.), not for SSH or git identity — those are forwarded from your host automatically.

1. **Install and sign in to `op`** on your host
2. **Open the project in a devcontainer** — the init script runs automatically and creates:
   - A 1Password vault (named `<project>-dev` by default)
   - A service account with vault access (token saved to `.op-token`)
3. **Add project secrets** to `.env.1password` (see [Adding Project Secrets](#adding-project-secrets))

On subsequent container rebuilds, the init script detects existing items and skips creation.

#### Existing 1Password Setup

If you already have a service account token, set these environment variables before opening the container:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
export OP_VAULT="your-vault-name"
```

For DevPod:

```bash
devpod up github.com/user/repo \
  --workspace-env OP_SERVICE_ACCOUNT_TOKEN=$OP_SERVICE_ACCOUNT_TOKEN \
  --workspace-env OP_VAULT=$OP_VAULT
```

## AI Agent Workflows

The template includes three workflows powered by Claude Code:

### `/plan` — Collaborative Planning

Explores your codebase, discusses tradeoffs, then files structured issues in Beads. Use this before `/work` for new features or epics.

### `/work` — Coordinated Implementation

Orchestrates multi-task work: creates worktrees, spawns implementer agents, runs three specialized PR reviews (correctness, test quality, architecture), then creates the PR.

### `/task` — Quick Implementation

Handles simple single-commit tasks end-to-end with test-first development and quality gates.

### Agent Skills

| Skill | Purpose |
|-------|---------|
| **planner** | Collaborative epic decomposition and architectural planning |
| **coordinator** | Orchestrates implementers, manages worktrees, runs PR reviews |
| **implementer** | Test-first development, commits and pushes |
| **task-completer** | Direct single-task completion |
| **reviewer-correctness** | PR review for bugs, security, error handling |
| **reviewer-tests** | PR review for test quality and integration coverage |
| **reviewer-architecture** | PR review for duplication and pattern consistency |
| **reviewer-plan** | Reviews filed issues for architectural problems |

## Adding Project Secrets

If using 1Password, add references to `.env.1password`:

```
API_KEY=op://${OP_VAULT}/my-api/key
DATABASE_URL=op://${OP_VAULT}/database/url
```

Then rebuild the container (or run `.devcontainer/setup-secrets.sh`). Secrets appear in `.env.local`.

## Customization

After scaffolding, customize for your project:

- **`CLAUDE.md`**: Add project-specific context (architecture, commands, conventions)
- **Quality gates**: Update skill files to reference your test runner and linter
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
│   ├── skills/                   # Agent skill definitions
│   └── commands/                 # Slash commands (/plan, /work, /task)
├── .beads/
│   └── config.yaml               # Issue tracking config
├── CLAUDE.md                     # Project context for Claude (populate per-project)
├── AGENTS.md.jinja               # Workflow documentation
├── .gitattributes                # Beads merge driver config
├── .gitignore.jinja
└── .env.example.jinja
```
