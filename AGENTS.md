# AGENTS.md — Project Complement to gentle-ai

**This project uses gentle-ai.** Before contributing, verify whether `gentle-ai` is available and report its version when installed. If it is unavailable, only suggest installation; do not run `gentle-ai install` automatically. gentle-ai enforces branch naming, issue-first, conventional commits, type labels, PR body template, and commit structure via its skills — this file does not duplicate those rules.

This file complements gentle-ai. gentle-ai's skills and built-ins are the source of truth for everything they cover. AGENTS.md only contains project-level rules that gentle-ai does not enforce.

gentle-ai already covers (do not duplicate here):

- Branch naming, issue-first, conventional commits, `type:*` labels, PR body template → `branch-pr` skill
- PR size budget (400 lines / `size:exception`) → `chained-pr` skill
- Commit structure (work unit, tests with code, docs with change) → `work-unit-commits` skill
- Skill registry freshness → `gentle-ai skill-registry refresh`
- Install / config rollback → snapshot system (see gentle-ai docs)

This file covers (gentle-ai does not):

- Project bootstrap (first-run procedure)
- Spanish documentation mirror and learning notebook
- In-code documentation conventions
- Repo-level branch protection verification
- Worktree usage and force-push policy
- Git-level rollback procedure
- Release criteria
- Non-UI SLOs reference
- UI design workflow (when applicable; full reference in `.docs/ui-workflow.md`)
- CLI tooling preference
- Cross-tool inheritance

**Precedence**: AGENTS.md extends gentle-ai but cannot contradict it on what gentle-ai explicitly covers. When this file mentions a skill (e.g., "see `branch-pr` skill"), gentle-ai's skill definition is authoritative.

---

## 0. Project bootstrap (first-run procedure)

When an agent reads this file in a project that has not been bootstrapped yet, it runs the procedure below before any other work. The procedure is minimal and idempotent — every step checks whether its target already exists.

### 0.1 Detection — "new project" test

The project is new if **any** of the following is missing at the project root:

- `.git/`
- `.gitignore`
- `documents-es/`

If none are missing, the project is already bootstrapped — skip this section.

### 0.2 Steps

Execute in order. Stop on first failure and surface the error to the user.

1. **Initialize git** with `git init -b main` at the project root.
2. **Create `.gitignore`** at the project root with common ignores:

   ```
   node_modules/
   .DS_Store
   *.log
   .env*
   dist/
   build/
   .codegraph/
   .worktrees/
   .atl/
   ```

3. **Create the Spanish mirror skeleton** at `documents-es/` with empty subdirectories `architecture/`, `specs/`, `proposals/`, `adr/`, `openspec/`, `learn/`. Place a `.gitkeep` in each so git tracks them.

### 0.3 When to skip

Do NOT bootstrap if any of these is true:

- Project is already bootstrapped (0.1 detection).
- User explicitly asks to skip bootstrap.
- Session is read-only (review, audit, planning without execution).

---

## 1. Documentation conventions

### 1.1 Spanish mirror for documentation

**Rule**: every artifact created in this project must have a Spanish mirror in `/documents-es/` (project root, lowercase). The mirror is created **at the same time** as the original. It is a **faithful translation** into neutral/professional Spanish — not a rewrite.

**Categories that require a mirror:**

- Documentation (READMEs, guides, onboarding, runbooks).
- Architecture decisions and ADRs.
- Specifications (technical specs, API contracts, data models).
- Proposals and PRDs.
- OpenSpec artifacts (`openspec/changes/*`, `openspec/specs/*`, proposals, designs, tasks, specs, verification reports, archive reports).
- Test plans and test reports.
- Changelogs and release notes.
- Learning notebook entries (see 1.2).

**Categories that do NOT require a mirror:**

- Project config files (`.gitignore`, `package.json`, lockfiles, CI configs).
- Source code (any language).
- Build outputs and generated files.
- Binary assets (images, fonts, compiled assets).
- Anything consumed by a machine rather than read by a human.

**Mirror rules:**

- File naming: same as the original, with `-es` suffix before the extension when it adds clarity (e.g. `architecture.md` → `architecture-es.md`).
- The mirror lives at the **same relative path** as the original, rooted at `/documents-es/` instead of the project root.
- Example: `docs/architecture.md` → `/documents-es/docs/architecture-es.md`.

**Recommended structure inside `/documents-es/`:**

- `/documents-es/architecture/` — architecture decisions
- `/documents-es/specs/` — specifications
- `/documents-es/proposals/` — proposals
- `/documents-es/adr/` — Architecture Decision Records
- `/documents-es/openspec/` — OpenSpec artifacts
- `/documents-es/learn/` — learning notebook (see 1.2)
- If no category fits, file lives at the root of `/documents-es/`.

**Decision test**: if a human reads it to understand the project, it goes to `/documents-es/`. If a machine reads it to run, build, or parse it, it does not.

### 1.2 Learning notebook `/documents-es/learn/`

**Rule**: every time something is implemented, it gets documented in `/documents-es/learn/` (lowercase, inside the Spanish mirror folder).

**When to update:**

- **One entry per feature or closed PR**, not per individual commit.
- Written **after the PR is merged into `main` with green CI** and **before** cleaning up the worktree.
- File naming: `/documents-es/learn/YYYY-MM-DD-short-feature-name.md`
  - Example: `/documents-es/learn/2026-08-08-autonomous-scientific-search.md`

**Required structure of each entry:**

Each learning file must have these sections in this order:

1. **What**: one or two sentences describing what was implemented.
2. **How**: the technical approach used (language, libraries, patterns, commands).
3. **Where**: main files and paths affected. Format `path/to/file` — short description.
4. **Why**: motivation, problem solved, decision taken.
5. **How it works**: how the feature operates in production or normal use. Concrete steps.
6. **Workflows**: workflows the feature touches or enables (CI, deploy, branching, tests).

If a section does not apply, omit it. Do not fill it with empty text.

**Proactive suggestions:**

The agent **must suggest** a candidate entry when it observes something worth learning, even if the user did not ask. Valid triggers:

- A non-obvious bug, gotcha, or edge case discovered.
- A pattern or convention established in the project.
- A trade-off or decision made and the reasoning behind it.
- A failure mode that would have been hard to recover from without context.

The suggestion is a conversational offer, not an automatic write. The user decides whether to commit it.

**Triggers that do NOT count** (do not suggest for these):

- Use of a standard library API or well-known syntax.
- Trivial refactors or mechanical renaming.
- Decisions already documented elsewhere in the repo.
- Anything that would not save a future agent time.

When in doubt, do not suggest. Better to under-suggest than to spam.

**Language**: neutral/professional Spanish throughout. No voseo, no slang, no CAPS for emphasis.

### 1.3 In-code documentation

In-code documentation follows the language's canonical convention:

- **TypeScript**: TSDoc (`/** ... */` on exported symbols).
- **JavaScript**: JSDoc.
- **Python**: docstrings per PEP 257.
- **Go**: godoc comments on exported symbols.
- **Other languages**: the canonical doc-comment convention for that ecosystem.

Public APIs (exported functions, classes, modules, types) must have docstrings explaining intent, parameters, return value, and any non-obvious behavior. Implementation details can be left undocumented. Project-specific additions or exceptions go in `DESIGN.md` or the project's style guide.

---

## 2. Git workflow complement

gentle-ai's `branch-pr`, `chained-pr`, and `work-unit-commits` skills already enforce the bulk of the git workflow (branch naming, issue-first, conventional commits, work-unit structure, 400-line cap, type labels). This section only adds what gentle-ai does not cover at the repo level.

### 2.1 Branch protection on `main` (mandatory setup)

The hosting platform (GitHub or GitLab) **must** enforce these protections on `main`:

- Merges only via approved PR. Direct pushes forbidden for everyone, including admins. Push access restricted to maintainers.
- No force pushes.
- No branch deletion.
- PR reviews are optional. A maintainer may merge their own PR after all required status checks and repository PR gates pass.

gentle-ai's `branch-pr` skill enforces the PR-side checks (issue reference, `status:approved`, type label, conventional commit format) via GitHub Actions. The platform-side branch protection above complements those checks.

Verify after setup **and after any change to repo settings**:

```bash
# GitHub
gh api repos/<owner>/<repo>/branches/main/protection

# GitLab
glab api projects/<id>/protected_branches/main
```

The protection endpoint must return a non-empty protection object with `required_status_checks` enabled. `required_pull_request_reviews` may be disabled.

### 2.2 Worktree usage (mandatory)

Every change happens inside a worktree, not the main checkout. Worktrees provide isolation and let multiple features progress in parallel.

```bash
# Create
git worktree add ../<repo>-worktrees/<branch-name>
cd ../<repo>-worktrees/<branch-name>
```

gentle-ai's `work-unit-commits` skill guides the commit structure inside the worktree.

After merge, clean up:

```bash
git worktree remove ../<repo>-worktrees/<branch-name>
git branch -d <branch-name>
git fetch --prune
git push origin --delete <branch-name>
```

### 2.3 Force-push policy

- Force-push **prohibited** on `main` (enforced by branch protection).
- Force-push **allowed** on personal feature branches during rebase.
- Never force-push a branch owned by someone else without explicit coordination.

### 2.4 Emergency procedures on `main`

gentle-ai covers rollback of its own install via snapshots. This section covers git-level emergency procedures on `main`: both **bad releases** (rollback) and **live bugs** (hotfix).

#### 2.4.1 Bad release — git revert

When a release on `main` causes problems:

1. Identify the bad commit(s).
2. Open a PR with `git revert <bad-commit>` against `main`.
3. After merge: the revert commit lands in `main` and subsequent releases include the rollback.

`git revert` is preferred over forward-fixing because it leaves an explicit record of what was rolled back. Use a forward fix only if the revert does not compile due to later changes.

#### 2.4.2 Live bug — emergency hotfix

When a feature on `main` has a critical bug in production (broken button, accessibility regression, security issue, data leak):

1. Branch from `main`: `fix/<short-desc>` (per `branch-pr` skill naming).
2. Worktree (§2.2), work-unit commits (`work-unit-commits` skill).
3. Implement the fix. Keep the diff minimal — fix the bug, don't refactor.
4. Open PR with `Closes #<incident-id>` and `type:bug` label.
5. Required status checks (CI green) and required reviews still apply. **No bypass of platform branch protection** — this is what makes trunk-based safe under pressure.
6. **Document bypassed testing gates in the PR body**: if any of the 4 pre-merge gates (visual, a11y, interaction, cross-browser for UI; unit/integration for backend) was skipped, explain why and create follow-up tickets to close the gap.
7. After merge: feature flag rollout is **skipped** — the fix ships to 100% of users. If the fix is high-risk, the code owner may require a partial rollout instead.
8. Tag the incident ID in the merge commit for traceability.
9. Post-mortem within 48 hours: root cause, what was bypassed, what's being done to prevent recurrence.

Emergency hotfix is **not** an excuse to skip review or CI. It's a documented acceleration. The audit trail is what matters.

### 2.5 Release criteria

A release is ready when:

- The set of features is tagged as a release candidate on `main`: `vX.Y.Z-rcN`.
- `CHANGELOG.md` is updated with the changes since the last release.
- CI is green on `main`.
- A code owner (per `CODEOWNERS` or designated by repo admins) approves the release.

After release: tag the release commit as `vX.Y.Z` (semver) on `main`. No additional branch is created — `main` carries the release tags directly.

### 2.6 Non-UI SLOs

For backend services, libraries, CLIs, and infrastructure, define SLOs in `ARCHITECTURE.md`. AGENTS.md does not enforce numbers — it requires that they be defined, measurable, and monitored.

Typical dimensions to define per project:

- **Response time**: e.g., p50 < 100ms, p99 < 500ms for API endpoints.
- **Throughput**: e.g., 1000 RPS sustained, 5000 RPS peak.
- **Error rate**: e.g., < 0.1% of requests return 5xx.
- **Queue lag**: e.g., p95 processing time < 30s for async jobs.
- **Availability**: e.g., 99.9% monthly uptime.
- **Dependency budgets**: e.g., DB query p99 < 50ms, external API calls < 200ms.

For the runtime observability pattern (a11y monitoring, Web Vitals, error tracking, product analytics), see `.docs/ui-workflow.md` stage 6 — the same observability principle applies to non-UI surfaces, just with project-specific metrics.

---

## 3. UI design workflow

**This section is a pointer.** Full reference lives at [`.docs/ui-workflow.md`](.docs/ui-workflow.md).

**Applicability**: this section applies **only** when the project ships user-facing UI. Skip it entirely for backend-only services, CLIs, infrastructure, libraries, scrapers, or pure backend work. For mobile native or non-web UI (iOS, Android, desktop), adapt the generator and stack choices accordingly — the audit step still applies.

**Rule** (summary): UI changes follow a tier-based pipeline:

- **Major changes** (new surface, layout shift, new component, redesign) → full pipeline: `generate → audit → design-review → implement → rollout → post-launch monitoring`.
- **Minor changes** (copy fix, spacing, color tweak, single element update) → lightweight flow: `implement + self-review with impeccable`.
- **Emergency UI fixes** in production → hotfix path in section 2.4.2, document the bypass in the PR body.

For UI standards (design system ownership, theming, responsive breakpoints, motion, i18n), the generator decision tree, audit checklist, design review process, implement gates (UI states, performance budget, pre-merge testing), rollout strategy, and post-launch monitoring — see [`.docs/ui-workflow.md`](.docs/ui-workflow.md).

---

## 4. CLI tooling preference

**Rule**: never use `cat`, `grep`, `find`, `sed`, `ls`. Use the modern replacements:

| Legacy | Modern | Purpose |
|--------|--------|---------|
| `cat`  | `bat`  | file viewer with syntax highlighting and paging |
| `grep` | `rg`   | content search (ripgrep) |
| `find` | `fd`   | file search |
| `sed`  | `sd`   | find-and-replace |
| `ls`   | `eza`  | directory listing with git awareness |

### 4.1 Install

```bash
brew install bat ripgrep fd sd eza
```

### 4.2 Fallback

If a modern tool is unavailable (e.g. on a constrained CI runner), fall back to the legacy command and document why in the PR body. Do not silently re-introduce legacy tools as the default.

---

## 5. Cross-tool inheritance

### 5.1 Maintaining AGENTS.md

When gentle-ai's skills change (renamed, replaced, deprecated, signature change), AGENTS.md must be updated in the same release cycle. A stale AGENTS.md is a defect: rules it states become unenforceable.

Manual audit procedure (run before each release, or whenever the skill registry changes):

1. Run `gentle-ai skill-registry list --json` to get the current skill set.
2. Diff against the skill mentions in this file (currently: `branch-pr`, `chained-pr`, `work-unit-commits`, `skill-registry refresh`, `impeccable`).
3. If anything drifted, update AGENTS.md and `.docs/ui-workflow.md` and commit them before tagging the release.

### 5.2 Security

AGENTS.md does not redefine security review. The canonical threat model for the agent runtime lives at [`gentle-ai/docs/review-authority-threat-model.md`](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/review-authority-threat-model.md). Projects with stricter security requirements (PII handling, financial data, auth systems, secret rotation) add their own `SECURITY.md` and reference it from `ARCHITECTURE.md`.

### 5.3 Tool defaults

Anything else not covered here is inherited from each developer's AI tooling defaults:

- Claude Code: `~/.claude/CLAUDE.md`
- OpenCode: `~/.config/opencode/AGENTS.md`
- Cursor / Aider / Codex: see the tool's documentation.

gentle-ai features (Engram persistent memory, CodeGraph, SDD workflow, RDD kill switch) are owned by gentle-ai and not duplicated here. See the gentle-ai repo for their documentation.

Cross-tool bash convention:

- Use `workdir`, not `cd ... && ...`.
