# pr-guardrails-lab

Sandbox for a strict PR pipeline: automated checks → AI code review → human
approval → manual merge. Everything here is meant to be lifted into a real repo
once it has been proven out.

```
feature/login  feature/payment  feature/dashboard
        └──────────── PR ────────────┘
                      │
     ┌────────────────▼─────────────────────┐
     │          AUTOMATED GATE               │
     │  1 PR guidelines   title·description· │
     │                    linked-issue·      │
     │                    not-wip·size       │
     │  2 ESLint      ┐                      │
     │  3 Prettier    │                      │
     │  4 TypeScript  ├── verify             │
     │  5 Tests+cov   │                      │
     │  6 Build       ┘                      │
     │  7 Security    ├── security · analyze │
     │  ───────────────────────────────────  │
     │  8 AI review       [advisory]         │
     └────────────────┬──────────────────────┘
          NO ─────────┴───────── YES
           │                      │
      dev fixes         reviewer approves
           ▲                      │
           │              Squash and merge
           │                      ▼
           │                    DEV
           │                      │
           │   gh workflow run promote.yml -f hop=dev-to-test
           │                      ▼
           │            PR: dev → test   (checks re-run)
           │            reviewer approves → merge commit
           │                      ▼
           │                    TEST
           │                      │
           │                QA / tester
           │          FAIL ───────┴─────── PASS
           └───────────┘                    │
                                            │
         gh workflow run promote.yml -f hop=test-to-main
                                            ▼
                            PR: test → main  (checks re-run)
                            tester approves → merge commit
                                            ▼
                                          MAIN
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

# 5. connect the AI reviewer (Claude, via your Pro/Max/Team subscription - no API key)
#    a. install the Claude GitHub app: https://github.com/apps/claude -> this repo only
#    b. generate a token tied to your subscription, then store it as a secret
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo balajikarthik2004/pr
#    Behaviour: .github/workflows/ai-review.yml (model, limits)
#               .github/review-guide.md          (what it looks for)

# 6. add your second account as a collaborator with write access
gh api -X PUT repos/balajikarthik2004/pr/collaborators/SECOND_ACCOUNT -f permission=push

# 7. create + protect all three branches (creates dev/test from main if missing)
#    'team' = 1 real approval per hop. Use 'solo' only if you have one account.
./scripts/setup-branch-protection.sh balajikarthik2004/pr team

# 8. make dev the default so new PRs target it automatically
gh repo edit balajikarthik2004/pr --default-branch dev
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
| `./scripts/seed-test-pr.sh clean` | Everything green. Claude posts a one-line summary and no findings. Merge button enabled. |
| `./scripts/seed-test-pr.sh lint` | `verify` fails at the lint step. Merge blocked. |
| `./scripts/seed-test-pr.sh hygiene` | `title`, `description`, `linked-issue`, `not-wip` all fail. |
| `./scripts/seed-test-pr.sh huge` | `size` fails at ~950 lines. Add the `large-pr` label, re-run, it passes. |
| `./scripts/seed-test-pr.sh bugs` | `verify` and `security` pass or mostly pass — **but the reviewer should flag** the index-mutation bug in `pruneExpired`, the unsalted MD5, the timing-unsafe token compare, and the N+1 in `loadNames`. This is the real test. |

Watch a run: `gh pr checks --watch`

### What to actually look for in the `bugs` scenario

Four defects are planted. Score the reviewer honestly:

1. `pruneExpired` — `splice` inside an index loop skips an element after each
   removal, so back-to-back expired sessions survive. **Correctness.**
2. `hashPassword` — unsalted MD5. **Security.**
3. `findSession` — `===` on a secret token is timing-unsafe. **Security**, and the
   one most likely to be missed.
4. `loadNames` — sequential `await fetch` in a loop. **Performance.**

Count hits, misses, and false positives. All four classes are named explicitly in
`.github/review-guide.md`, so a miss means the guide needs a sharper example of
that class — edit it and re-run the `AI Code Review` job. Still missing things?
Switch `--model` to `claude-opus-5-5` in `ai-review.yml` for that run. Too much noise
instead? Tighten the confidence rule in the workflow prompt.

Clean up when done: `git push origin --delete <branch>` and close the PRs.

## Moving to the org

1. Copy `.github/` and `CONTRIBUTING.md` into the target repo.
2. Rewrite `CODEOWNERS` to use teams (`@org/platform`), not usernames.
3. Install the Claude GitHub app on the org and set `CLAUDE_CODE_OAUTH_TOKEN` (or
   `ANTHROPIC_API_KEY`) as an org secret, from an org-owned account rather than
   one person's plan. `.github/review-guide.md` is the part worth tuning per repo.
4. `./scripts/setup-branch-protection.sh org/repo prod` — `test` needs 1 dev
   approval, `main` needs 1 tester approval with CODEOWNERS review, admin
   enforcement on both. Put your QA team in CODEOWNERS so the tester approval
   on `main` is routed automatically.
5. Roll out in stages. Turning all of this on at once on a busy repo gets it
   switched off within a fortnight. Order: protection + 1 approval → `verify` →
   hygiene (title only, then the rest) → AI review advisory → security blocking.
