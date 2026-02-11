# Plan: agent-workflow Repository

## Goal

Create a new `agent-workflow` repo that gives any GitHub project a production-grade, agent-friendly development workflow. Two commands (`/plan`, `/work`), GitHub Issues with sub-issues for tracking, GitHub Actions for automated review and guardrails, and a curl-able installer.

Separate from `devcontainer-template` — the workflow is independent of devcontainers.

## Design Reference

Full design doc: `history/agent-workflow-design.md`

## Key Design Decisions

- **Two commands only:** `/plan` and `/work`. No `/merge`, no `/cleanup`.
- **`/work #N` is the universal entry point:** Creates or reuses branch, rebases if behind, implements (leaf) or orchestrates (non-leaf), handles review findings on re-runs, opens/updates PR.
- **GitHub Issues with sub-issues:** Native hierarchy, native `blocked-by`/`blocking` dependencies. No beads, no external tracker.
- **Hierarchical branching:** Branch hierarchy mirrors issue hierarchy. PRs target parent's branch.
- **GitHub auto-merge:** Orchestrator check gates merge. When it passes + other checks pass, auto-merge proceeds. No `/merge` command.
- **Installer:** `curl | bash` script that copies files into existing projects. Merges config, doesn't overwrite.
- **Three reviewers + guardrails** via GitHub Actions (`claude -p`).

---

## Epic 1: Repository Bootstrap

Create the repo structure and foundation files.

### Tasks

1.1. **Create GitHub repo and basic structure**
- Create `jdelfino/agent-workflow` on GitHub
- Add README.md with project overview, philosophy, quick start
- Add LICENSE (MIT)
- Copy design doc to `docs/design.md`
- Create directory structure:
  ```
  agent-workflow/
  ├── workflow/           # Files copied by installer
  │   ├── .claude/
  │   │   ├── skills/
  │   │   └── commands/
  │   ├── .github/
  │   │   ├── workflows/
  │   │   ├── agent-workflow/
  │   │   └── ISSUE_TEMPLATE/
  │   └── CLAUDE.md      # Starter template
  ├── install.sh          # The installer
  ├── setup.sh            # Branch protection setup
  ├── docs/
  │   └── design.md
  └── README.md
  ```

---

## Epic 2: Skills & Commands (Layer 2)

Rewrite all skills for GitHub Issues + hierarchical branching. This is the core value.

### Tasks

2.1. **Write AGENTS.md**
- Workflow overview (plan → work → automated review → fix → merge)
- GitHub Issues conventions (sub-issues, labels, dependencies)
- `/plan` and `/work` usage
- Issue structure requirements (self-contained, acceptance criteria)
- Landing the plane checklist (adapted for gh CLI, no beads)

2.2. **Write planner skill**
- Explore codebase, discuss with user, file issues
- Create parent issue via `gh issue create`
- Create child issues as sub-issues with dependencies
- Each child: summary, files to modify, implementation steps, acceptance criteria
- Run plan reviewer after filing
- Rewrite from current beads-based planner

2.3. **Write coordinator/work skill**
- `/work #N` entry point — the recursive orchestrator
- Determine parent issue → base branch (parent's branch or main)
- Create branch `feat/{N}-{slug}` or reuse existing
- Rebase on parent branch if behind
- If leaf: spawn implementer subagent
- If non-leaf: create PR, work through unblocked children
- Handle review findings on re-runs (same as working children)
- Open/update PR with `fixes #N`
- Rewrite from current beads-based coordinator

2.4. **Write implementer skill**
- Pure development: write tests first, implement, run quality gates
- No issue management, no commits (coordinator handles that)
- Mostly unchanged from current — remove beads references
- Adapt "landing the plane" for the new workflow

2.5. **Write three reviewer skills**
- Correctness, tests, architecture — same concerns as current
- Output: create GitHub child issues under the PR's linked issue
- Labels: `blocking`, `should-fix`, `suggestion`
- Set `blocking` issues as blocking the parent via GitHub dependency API
- Rewrite output format from beads to `gh issue create`

2.6. **Write plan reviewer skill**
- Validate filed issues against codebase
- Check for pattern consistency, duplication risks, missing tasks
- Verify dependencies are correct
- Rewrite from beads to GitHub Issues

2.7. **Write /plan command**
- Invokes planner skill
- Accepts issue ID or description

2.8. **Write /work command**
- Invokes coordinator/work skill
- Accepts issue ID or description
- Handles both fresh work and re-runs

2.9. **Write .claude/settings.json**
- Permissions: `Bash(gh:*)`, `Bash(git:*)`
- Session start hook: display workflow summary
- No beads MCP server

---

## Epic 3: CLAUDE.md Starter Template

A starter CLAUDE.md that adopting projects customize.

### Tasks

3.1. **Write CLAUDE.md template**
- Section for project overview (user fills in)
- Section for commands and key files (user fills in)
- Pre-populated workflow section referencing AGENTS.md
- Issue tracking conventions (GitHub Issues, not beads)
- Quality gates section (test, lint, typecheck — user fills in commands)

---

## Epic 4: GitHub Actions (Layer 3 + 4)

Automated review, orchestrator check, and guardrail library.

### Tasks

4.1. **Write PR review workflow** (`pr-review.yml`)
- Trigger: PR opened or synchronized
- Run 3 reviewer skills in parallel via `claude -p`
- Parse `fixes #N` from PR description to determine parent issue
- Each reviewer creates child issues with severity labels

4.2. **Write orchestrator status check** (`orchestrator-check.yml`)
- Trigger: issue events + PR pushes
- Parse `fixes #N`, check for open blocking children
- If blockers: fail check
- If clear: assess whether re-review is needed (lightweight `claude -p`)
- Respect cycle cap from config
- Report pass/fail as GitHub check run

4.3. **Write guardrail: scope enforcement** (`guardrail-scope.yml`)
- Compare changed files against files listed in linked issue
- Check for non-stale PR approval (override)
- Report via GitHub check run with annotations

4.4. **Write guardrail: test-to-code ratio** (`guardrail-test-ratio.yml`)
- Calculate test lines vs implementation lines in PR diff
- Configurable threshold from config.yaml
- Report via check run

4.5. **Write guardrail: dependency changes** (`guardrail-dependencies.yml`)
- Detect changes to package.json, requirements.txt, go.mod, etc.
- Require justification in PR body or linked issue
- Report via check run

4.6. **Write guardrail: API surface changes** (`guardrail-api-surface.yml`)
- Detect changes to exports, public interfaces, API endpoints
- Report via check run with annotations

4.7. **Write guardrail: commit messages** (`guardrail-commits.yml`)
- Enforce conventional commits, issue reference, max length
- Report via check run

4.8. **Write workflow configuration** (`.github/agent-workflow/config.yaml`)
- Re-review cycle cap
- Per-check enable/disable and conclusion level
- Test ratio threshold
- Approved file creation directories

4.9. **Write issue templates**
- `task.yml` — structured task for agent consumption
- `review-finding.yml` — template for reviewer-created issues

---

## Epic 5: Setup & Installation

The distribution layer — how users adopt the workflow.

### Tasks

5.1. **Write setup.sh**
- Configure branch protection on main via `gh api`
- Set required status checks (orchestrator, guardrails)
- Enable auto-merge
- Idempotent — safe to re-run

5.2. **Write install.sh**
- Download workflow files from GitHub raw
- Copy skills and commands (safe — new dirs)
- Merge .claude/settings.json (add permissions, don't overwrite)
- Append to CLAUDE.md (add workflow section if not present)
- Write AGENTS.md (warn if exists)
- Copy .github/ workflows and config
- Copy issue templates
- Report what was installed/skipped

5.3. **Write README.md**
- Philosophy and problem statement
- Quick start (curl | bash)
- What you get (skills, Actions, guardrails)
- Configuration reference
- How it works (link to design doc)

---

## Epic 6: Clean up devcontainer-template

After agent-workflow is shipped, strip redundant content.

### Tasks

6.1. **Remove duplicated skills and commands from devcontainer-template**
- Remove `.claude/skills/` and `.claude/commands/` from template
- Remove AGENTS.md from template
- Add agent-workflow installation to post-create.sh
- Update README to reference agent-workflow

6.2. **Remove 1Password integration**
- Remove all 1pw scripts and Copier conditionals
- Remove `use_1password` and `op_vault` from copier.yaml
- Simplify devcontainer.json.jinja (no initializeCommand/setup-secrets)
- Update README

---

## Dependency Graph

```
Epic 1 (Bootstrap)
  └── Epic 2 (Skills) ─── depends on Epic 1
  └── Epic 3 (CLAUDE.md) ─── depends on Epic 1
  └── Epic 4 (Actions) ─── depends on Epic 2 (reviewers must exist)
  └── Epic 5 (Install) ─── depends on Epics 2, 3, 4 (needs all content)
       └── Epic 6 (Cleanup) ─── depends on Epic 5 (install must work first)
```

Within Epic 2, ordering:
- 2.1 (AGENTS.md) first — other skills reference it
- 2.2 (planner) and 2.3 (coordinator) can parallelize
- 2.4 (implementer) depends on 2.3
- 2.5 (reviewers) depends on 2.3
- 2.6 (plan reviewer) depends on 2.2
- 2.7-2.9 (commands, settings) depend on their respective skills
