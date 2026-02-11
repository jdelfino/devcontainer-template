# Agent-Friendly Development Workflow Framework

## Design Document — Draft

---

## Problem

AI coding agents forget instructions as context grows. The current approach to solving this — better prompts, better CLAUDE.md files, smaller tasks — helps but is fundamentally probabilistic. Agents will still occasionally skip tests, commit to main, bundle unrelated changes, or add unnecessary dependencies.

The solution isn't better instructions. It's structural enforcement — a development environment where the rules are enforced by the platform, not by the agent's memory. The same way CI/CD pipelines solved "developers forgetting to run tests" a decade ago.

The secondary problem: mature development processes (branch protection, automated review, structured task decomposition, dependency tracking) exist at well-run companies but are absent from most solo developer and small team workflows. The setup cost and ongoing overhead don't make sense at small scale — unless agents are doing the work, in which case the overhead is near zero.

## Core Thesis

Ship a GitHub template repo that gives any project a production-grade, agent-friendly development workflow. The enforcement is structural (GitHub branch protection, Actions, status checks). The intelligence is in skills (planning, implementation, review prompts). The result: agents work autonomously when things are clean, and humans get pulled in with focused context only when something needs judgment.

## System Architecture

### Layer 1: Enforcement (GitHub Configuration)

This is the skeleton. Non-negotiable, deterministic, platform-enforced.

- **Branch protection on main.** No direct pushes. PRs required. Status checks required. No exceptions.
- **Required status checks.** Tests, linting, the orchestrator check (see Layer 3), and all enabled guardrail checks must pass before merge. Guardrail checks use native GitHub check run conclusions (`success`, `neutral`, `action_required`) to report results — no custom schema needed.
- **Auto-merge enabled.** When all checks pass and required reviews (if any) are satisfied, the PR merges automatically. The default path is fully automated.
- **Setup script.** A `setup.sh` that configures all of the above via `gh api` commands. Run once, enforcement is in place.

### Layer 2: Intelligence (Skills)

Prompts and conventions that define how agents interact with the project. Generic defaults ship with the template; projects tune them over time.

#### Planning Skill

Human-in-the-loop, run from a Claude Code terminal. Takes a feature description or problem statement and decomposes it into:

- A **parent issue** describing the feature/epic
- **Child issues** for each task, structured with:
  - What to change and why
  - Acceptance criteria
  - Relevant files
  - Dependencies on other issues (using GitHub's native `blocked-by` / `blocking` relationships)
- **Sub-issue hierarchy** for complex decomposition (grandchildren, etc.)

Each child issue is scoped to be completable in a single agent session with fresh context. This is the key constraint — if a task can't be done in one session, the planning is wrong.

#### Implementation Skill

Triggered by `/work #N` from a Claude Code terminal. The coordinator:

- Picks up the issue
- Creates a branch
- Spawns implementer subagents for the work
- Opens a PR when implementation is complete
- PR description includes `fixes #N` referencing the parent issue

One issue, one session, one PR. Fresh context every time.

#### Reviewer Skills

Three specialized reviewers, each a separate skill:

- **Correctness reviewer** — bugs, error handling, security issues, logic errors
- **Test reviewer** — test coverage, edge cases, test quality, integration coverage
- **Architecture reviewer** — duplication, pattern consistency, separation of concerns, unnecessary complexity

Each reviewer produces structured findings with severity levels.

#### Fix Skill

Triggered by `/cleanup #N` from a Claude Code terminal. Works through blocking issues filed by reviewers, pushes fixes to the PR branch, closes issues as they're resolved. Same coordinator/subagent pattern as implementation.

### Layer 3: Orchestration (GitHub Actions)

Event-driven workflows that wire everything together. Each Action is stateless and triggered by GitHub events.

#### PR Review Workflow

**Trigger:** PR opened or synchronized (new commits pushed)

**Action:**
1. Run three reviewer skills in parallel via `claude -p`
2. Each reviewer creates child issues under the parent issue (parsed from `fixes #N` in PR description)
3. Issues are labeled by severity: `blocking`, `should-fix`, `suggestion`
4. `blocking` issues are set as blocking the parent issue using GitHub's native dependency API

#### Dependency Resolution Workflow

**Trigger:** Issue closed

**Action:**
1. Check if the closed issue was blocking any other issues
2. For newly-unblocked issues, update labels (e.g., add `ready`)
3. This enables the status check to re-evaluate

#### Orchestrator Status Check

**Trigger:** Issue events (opened, closed, labeled, unlabeled) and PR pushes

This is the brain of the system. Single Action that:

1. Parses `fixes #N` from the PR description
2. Checks if the referenced parent issue has any open `blocking` child issues
3. **If blockers exist:** Report failing status check. PR cannot merge.
4. **If no blockers and this is a new "all clear":** Run a lightweight `claude -p` call to assess whether fixes since last review warrant a re-review (based on diff size, complexity, scope of changes)
5. **If re-review warranted and under the cycle cap (default: 3 rounds):** Trigger the PR Review Workflow again
6. **If re-review not warranted, or cap reached:** Report passing status check. Auto-merge proceeds (unless human review is required).

#### Guardrail Checks

**Trigger:** PR opened or synchronized

Each guardrail check runs as an independent GitHub Actions job and reports its result as a native GitHub check run. No custom schema or collector Action — each check uses GitHub's built-in check run conclusions:

- **`success`** → check passed, nothing to report
- **`neutral`** → warning-level finding; visible in PR checks UI but non-blocking
- **`action_required`** → escalation-level finding; blocks merge until resolved

Checks can attach **annotations** to specific files and lines in the PR diff, so findings appear inline where they matter — not buried in a comment thread.

Branch protection requires all guardrail checks to pass. A `neutral` conclusion satisfies branch protection. An `action_required` conclusion blocks the PR. The human sees exactly which checks need attention in the standard PR checks UI without any custom aggregation layer.

When any check reports `action_required`, it also adds a `requires-human-review` label to the PR and posts a summary comment with the specific context needed for the human to make a decision.

### Layer 4: Guardrail Check Library

Deterministic checks that catch things agents do wrong more often than humans. Each check is an independent GitHub Actions job that reports its findings using native GitHub check runs.

#### Shipped with v1

**Scope enforcement.** Compare files changed in the PR against files listed in the issue. Flag changes to files not mentioned in the task description. Catches agent scope creep — the "helpful" refactoring of nearby code.

**Test-to-code ratio.** Ratio of test lines to implementation lines in the PR. Configurable threshold (default: 0.5). Catches the most common agent failure: skipping or phoning in tests.

**Dependency change detection.** Diff `package.json`, `requirements.txt`, `go.mod`, etc. against main. New dependencies require justification in the PR body or linked issue. Agents add dependencies like candy.

**API surface change detection.** Detect changes to exported functions, public interfaces, API endpoints. These have outsized downstream impact that agents don't understand without organizational context.

**Single-concern validation.** Analyze the PR diff for multiple unrelated changes. Can be a simple heuristic (common directory prefix) or an LLM-assisted assessment.

**File creation gate.** Flag new files created outside approved directories or new top-level modules. Prevents agents from creating `utils/helpers/misc.py`.

**Commit message structure.** Enforce format (conventional commits, issue reference, max length). Deterministic, zero ambiguity.

**Configuration drift detection.** Flag changes to `.env`, config files, infrastructure definitions. These changes have outsized impact and agents modify them casually.

#### Check Architecture

Each check is a standalone GitHub Actions job that uses the [Checks API](https://docs.github.com/en/rest/checks) to report results. No custom schema — checks use GitHub's native primitives:

**Check run conclusions map to severity:**

| Severity | Check Run Conclusion | Effect |
|----------|---------------------|--------|
| Pass | `success` | No action needed |
| Warn | `neutral` | Visible in PR checks UI, non-blocking |
| Escalate | `action_required` | Blocks merge, adds `requires-human-review` label |

**Annotations** attach findings to specific files and lines:
```yaml
# Example: scope enforcement check reports via GitHub check run
- name: Report scope check
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.checks.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        head_sha: context.sha,
        name: 'guardrail/scope-enforcement',
        conclusion: 'action_required',
        output: {
          title: 'Scope enforcement: 2 files outside task scope',
          summary: 'PR modifies files not listed in issue #17',
          annotations: [
            {
              path: 'src/auth/middleware.ts',
              start_line: 1, end_line: 1,
              annotation_level: 'warning',
              message: 'This file is not listed in the task scope for issue #17'
            }
          ]
        }
      });
```

**Configuration:** Each check has a config entry in `.github/agent-workflow/checks.yaml`. The config controls which checks are enabled and what conclusion they report:
```yaml
scope-enforcement:
  enabled: true
  conclusion: action_required  # or "neutral" or disabled

test-ratio:
  enabled: true
  conclusion: action_required
  threshold: 0.5

dependency-changes:
  enabled: true
  conclusion: action_required
```

This architecture allows the check library to grow over time. Contributing a new check means writing a GitHub Actions job that analyzes the PR and reports a check run — standard GitHub API, no framework to learn.

### Layer 5: Human Escalation

Human escalation is handled through GitHub's native check run system rather than a custom orchestration layer.

When a guardrail check reports `action_required`, or when the re-review cycle cap is reached, or when the orchestrator status check determines human judgment is needed:

1. `requires-human-review` label is added to the PR
2. Branch protection requires an approving review when this label is present
3. The check run's `output.summary` and annotations provide the specific context needed for the human to make a decision — visible directly in the PR checks UI
4. The human reviews the *decision*, not the whole PR. "This agent added a new dependency — here's what it is and why. Approve or reject."

PRs (or the implementation agent) can also proactively add `requires-human-review` at any point if the agent determines the changes warrant human judgment.

**Escalation gradient (all using native GitHub check conclusions):**

| Situation | Check Conclusion | Effect |
|-----------|-----------------|--------|
| Clean PR, no guardrails tripped | All `success` | Auto-merge |
| Minor flags (commit message, slightly low test ratio) | `neutral` | Visible in checks UI, non-blocking |
| Significant flags (scope creep, new deps, API changes) | `action_required` | Human review required with focused context |
| Re-review cap exceeded | `action_required` | Human review required |
| Agent self-identifies need for human judgment | Adds label directly | Human review required |

## Workflow: End to End

### 1. Planning (Human + Claude Code terminal)

```
human> /plan "Add rate limiting to the API"
```

Claude Code explores the codebase, discusses tradeoffs with the human, then creates:
- Parent issue #20: "Add rate limiting to the API"
  - Child issue #21: "Add rate limiting middleware" (no dependencies)
  - Child issue #22: "Add rate limit configuration" (blocked by #21)
  - Child issue #23: "Add rate limit headers to responses" (blocked by #21)
  - Child issue #24: "Add rate limit exceeded error handling" (blocked by #22, #23)
  - Child issue #25: "Add rate limiting documentation" (blocked by #24)

### 2. Implementation (Human + Claude Code terminal)

```
human> /work #21
```

Coordinator creates branch `feat/21-rate-limiting-middleware`, spawns implementer subagents, opens PR with `fixes #20` in the description when done.

### 3. Automated Review (GitHub Actions)

PR open triggers the review workflow. Three reviewers run in parallel via `claude -p`. Findings:

- Correctness reviewer creates issue #26: "Missing null check on request.ip" → severity: `blocking` → set as blocking #20
- Test reviewer creates issue #27: "No test for concurrent request handling" → severity: `blocking` → set as blocking #20
- Architecture reviewer creates issue #28: "Rate limit store should be injected, not hardcoded" → severity: `should-fix` → child of #20 but not blocking

Status check runs: #20 is blocked by #26 and #27. Check fails. PR can't merge.

### 4. Guardrail Checks (GitHub Actions)

Guardrail checks run in parallel with review, each as an independent check run. All report `success` — implementation stayed in scope, test ratio is good, no new dependencies, no API surface changes. All checks show green in the PR checks UI. No human review required.

### 5. Fixes (Human + Claude Code terminal)

```
human> /cleanup #20
```

Fix skill works through blocking issues #26 and #27. Pushes commits to the PR branch. Closes both issues.

### 6. Re-evaluation (GitHub Actions)

Issue close events trigger the status check. #20 has no more open blockers. Status check runs `claude -p` to assess: fixes were small and surgical (null check + one new test). Re-review not warranted. Check goes green.

Auto-merge proceeds. PR merges. `fixes #20` closes the parent issue. #25 (documentation) becomes unblocked. Non-blocking issue #28 (dependency injection refactor) remains in the backlog with full context.

### 7. Next Task

#22 and #23 were blocked by #21 (now closed via PR merge). Dependency resolution workflow unblocks them. Human picks up the next task:

```
human> /work #22
```

Cycle repeats.

## Template Repo Contents

```
agent-workflow-template/
├── .github/
│   ├── workflows/
│   │   ├── pr-review.yml              # Triggers reviewers on PR open
│   │   ├── orchestrator-check.yml     # Status check: blocker evaluation + re-review
│   │   ├── dependency-resolution.yml  # Unblocks issues when blockers close
│   │   ├── guardrail-scope.yml        # Scope enforcement (native check run)
│   │   ├── guardrail-test-ratio.yml   # Test-to-code ratio (native check run)
│   │   ├── guardrail-dependencies.yml # Dependency change detection (native check run)
│   │   ├── guardrail-api-surface.yml  # API surface change detection (native check run)
│   │   └── guardrail-commits.yml      # Commit message structure (native check run)
│   ├── agent-workflow/
│   │   └── config.yaml                # Workflow configuration (re-review cap, check thresholds, etc.)
│   └── ISSUE_TEMPLATE/
│       ├── task.yml                    # Structured task template for agent consumption
│       └── review-finding.yml         # Template for reviewer-created issues
├── .claude/
│   ├── settings.json
│   ├── skills/
│   │   ├── planner.md                 # Planning skill
│   │   ├── coordinator.md             # Implementation coordinator
│   │   ├── implementer.md             # Implementation agent
│   │   ├── reviewer-correctness.md    # Correctness review skill
│   │   ├── reviewer-tests.md          # Test quality review skill
│   │   ├── reviewer-architecture.md   # Architecture review skill
│   │   └── cleanup.md                 # Fix/cleanup skill
│   └── commands/
│       ├── plan.md                    # /plan command
│       ├── work.md                    # /work command
│       └── cleanup.md                 # /cleanup command
├── CLAUDE.md                          # Starter project context (fill in per project)
├── setup.sh                           # Configures branch protection via gh api
└── README.md
```

## What Ships in v1

- Setup script for branch protection and required status checks
- Orchestrator status check Action (the brain — blocker evaluation, re-review assessment)
- PR review workflow invoking three reviewer skills via `claude -p`
- Dependency resolution workflow
- Guardrail checks as independent workflow files using native GitHub check runs (scope, test ratio, dependency changes, API surface, commit messages)
- Human escalation via `action_required` check conclusion + `requires-human-review` label
- Planning, implementation, and cleanup skills (adapted from devcontainer-template)
- Issue templates for tasks and review findings
- Starter CLAUDE.md and workflow configuration
- README explaining the philosophy and setup

## What's v2

- **Autonomous fix agents in Actions.** Fix agents running on the Actions runner directly, with a dev environment set up in the workflow. Removes the manual `/cleanup` step for well-defined fixes.
- **Autonomous planning trigger.** File a GitHub issue to kick off planning without a terminal. Human reviews the plan (approve/reject the issue decomposition) before work begins.
- **Autonomous task dispatch.** When an issue becomes unblocked and is labeled `ready`, an Action automatically invokes `/work` via `claude -p`. The full pipeline runs without human intervention for straightforward tasks.
- **Expanded check library.** Community-contributed guardrail checks for specific frameworks, languages, and domains. Each check is just a GitHub Actions workflow file that reports a check run — no framework to learn. Django migration checks, TypeScript type export checks, security-focused checks for regulated industries, etc.
- **Maintenance passes.** Periodic workflows that sweep `should-fix` and `suggestion` issues from the backlog, group them by file or concern, and open cleanup PRs.
- **Metrics and reporting.** Track review cycle counts, guardrail trip rates, fix success rates. Surface patterns — if the same guardrail trips repeatedly, the CLAUDE.md or skills need tuning.

## Open Questions

1. **Authentication for `claude -p` in Actions.** Two supported paths: (a) `ANTHROPIC_API_KEY` — a Console API key with per-token billing, stored as a GitHub Secret. This is the recommended path: unambiguous ToS compliance, no ban risk, predictable billing. (b) `CLAUDE_CODE_OAUTH_TOKEN` — generated via `claude setup-token`, bills against Pro/Max subscription allocation. Officially supported by claude-code-action but closer to the patterns that have triggered false-positive bans. Use API key for CI/CD, keep subscription for interactive development. Need to validate cost predictability — a busy repo could generate significant API spend from automated reviews.

2. **False-positive ban risk.** Even with legitimate API key usage, rapid-fire `claude -p` invocations from Actions runners could theoretically trip Anthropic's abuse filters. Need to test this at realistic volumes and potentially add rate limiting between invocations.

3. **Re-review assessment prompt quality.** The `claude -p` call that decides whether fixes warrant re-review is a judgment call. Needs careful prompt engineering and testing to avoid both over-triggering (every fix gets re-reviewed, wasting cycles) and under-triggering (bad fixes slip through).

4. **Check library contribution model.** Contributing a check is just adding a workflow file that reports a GitHub check run — low barrier. But curation still matters. Bad checks that generate false `action_required` conclusions will erode trust in the system. Need a review process for contributed checks and clear guidelines on when to use `neutral` vs `action_required`.

5. **Multi-repo / monorepo support.** v1 assumes one repo, one project. Monorepos with multiple services would need per-path configuration for guardrails and potentially separate review workflows per service.

6. **Cost model.** Each reviewer is a `claude -p` call. Three reviewers per PR, plus re-review assessments, plus potential re-review rounds. For a solo dev doing 5 PRs/day, this could be $10-50/day in API costs depending on diff sizes. Need to surface cost estimates clearly.
