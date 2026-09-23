# pr-guardrails-lab

Sandbox for a strict PR pipeline: automated checks → AI code review → human
approval → manual merge. Everything here is meant to be lifted into a real repo
once it has been proven out.

```
PR opened
  ├─ verify        lint · typecheck · test+coverage · build      [blocking]
  ├─ security      gitleaks · semgrep · npm audit · dep review   [blocking]
  ├─ analyze       CodeQL (GHAS only)                            [blocking]
  ├─ title / description / linked-issue / not-wip / size         [blocking]
  └─ ai-review     Claude posts inline comments                  [advisory]
        ↓
  human approves (stale approvals dismissed on new pushes)
        ↓
  Squash and merge — clicked by a person, auto-merge disabled
```

## Setup

```bash
# 1. deps
npm ci

# 2. prove the gates work locally before trusting them in CI
npm run verify

# 3. CODEOWNERS is already set to @balajikarthik2004

# 4. create the repo and push
gh repo create pr --private --source=. --remote=origin --push

# 5. auth for the AI reviewer (uses your Claude subscription, not an API key)
claude setup-token                    # prints sk-ant-oat01-...
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo balajikarthik2004/pr

# 6. lock down main
./scripts/setup-branch-protection.sh balajikarthik2004/pr sandbox
```

If the repo has GitHub Advanced Security (any public repo, or an org on
Enterprise), turn on CodeQL and dependency review:

```bash
gh variable set HAS_ADVANCED_SECURITY --body true
```

## Test plan

Each scenario proves one gate. Run them one at a time and confirm the expected
result before moving on.

| Command | Expected |
|---|---|
| `./scripts/seed-test-pr.sh clean` | Everything green. AI posts one "no issues" comment. Merge button enabled. |
| `./scripts/seed-test-pr.sh lint` | `verify` fails at the lint step. Merge blocked. |
| `./scripts/seed-test-pr.sh hygiene` | `title`, `description`, `linked-issue`, `not-wip` all fail. |
| `./scripts/seed-test-pr.sh huge` | `size` fails at ~950 lines. Add the `large-pr` label, re-run, it passes. |
| `./scripts/seed-test-pr.sh bugs` | `verify` and `security` pass or mostly pass — **but the AI should flag** the index-mutation bug in `pruneExpired`, the unsalted MD5, the timing-unsafe token compare, and the N+1 in `loadNames`. This is the real test. |

Watch a run: `gh pr checks --watch`

### What to actually look for in the `bugs` scenario

Four defects are planted. Score the reviewer honestly:

1. `pruneExpired` — `splice` inside an index loop skips an element after each
   removal, so back-to-back expired sessions survive. **Correctness.**
2. `hashPassword` — unsalted MD5. **Security.**
3. `findSession` — `===` on a secret token is timing-unsafe. **Security**, and the
   one most likely to be missed.
4. `loadNames` — sequential `await fetch` in a loop. **Performance.**

Count hits, misses, and false positives. If it invents problems, tighten the
confidence threshold in the prompt. If it misses (1), that's the signal the prompt
needs a concrete example of the class.

Clean up when done: `git push origin --delete <branch>` and close the PRs.

## Moving to the org

1. Copy `.github/` and `CONTRIBUTING.md` into the target repo.
2. Rewrite `CODEOWNERS` to use teams (`@org/platform`), not usernames.
3. Set `ANTHROPIC_API_KEY` as an **org-level** secret scoped to the repos that need it.
4. `./scripts/setup-branch-protection.sh org/repo prod` — 1 approval, CODEOWNERS
   review required, admin enforcement on.
5. Roll out in stages. Turning all of this on at once on a busy repo gets it
   switched off within a fortnight. Order: protection + 1 approval → `verify` →
   hygiene (title only, then the rest) → AI review advisory → security blocking.
