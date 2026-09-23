# Contributing

These rules are enforced by CI. Nothing here relies on someone remembering it.

## Branching

Two long-lived branches:

| Branch | What it is | How code gets in |
|---|---|---|
| `test` | Integration branch. QA works here. | PR from a feature branch, full gate, **squash merge** |
| `main` | Production. | PR from `test` only, tester approval, **merge commit** |

- Branch off `test`, not `main`. Name it `feat/…`, `fix/…`, `chore/…`.
- Never push directly to either branch. Both are protected.
- Rebase onto `test` before requesting review.
- **Never squash-merge `test` into `main`.** Use "Create a merge commit". Squashing
  makes the two branches diverge and every later release PR shows phantom conflicts.

## Pull request rules

| Rule | Limit | Enforced by |
|---|---|---|
| Title format | Conventional Commits, subject 10–72 chars, lowercase, no trailing period | `title` |
| Description | All four template sections, filled in, ≥80 chars | `description` |
| Linked work | `#123` or `ABC-456` in title or body | `linked-issue` |
| Not a draft, no WIP marker | — | `not-wip` |
| Size | ≤800 changed lines, ≤50 files (lockfiles and generated excluded) | `size` |
| Lint / format / types / tests / build | all pass | `verify` |
| Coverage | lines ≥80%, branches ≥70% | `verify` |
| Secrets, SAST, vulnerable deps | no high-severity findings | `security` |

Over the size limit for a genuine reason? Add the `large-pr` label **and** justify it
in the description. The label waives the check and leaves an audit trail.

## The AI reviewer

Every non-draft PR gets an automated review from Gemini Code Assist. It posts a
summary comment plus up to 10 inline comments, and only for findings at MEDIUM
severity or above. What it looks for is defined in `.gemini/styleguide.md` — that
file is the review policy, and it is worth editing when the reviewer is wrong.

**It does not gate the merge.** It is a reviewer, not a judge. But:

- Every one of its comments must be resolved or replied to — "Require conversation
  resolution" is on, so unanswered threads block the merge button.
- Ask for another pass by commenting `/gemini review` on the PR.
- Disagreeing is fine and expected. Reply saying why, then resolve.
- A human still reviews the code. The AI catches a class of thing humans skim past;
  it does not catch intent, architecture, or whether the change should exist.

## Review and merge

### Stage 1 — your change into `test`

1. Open a PR from your feature branch into `test`. All eight checks and the AI
   reviewer start automatically.
2. Fix what CI finds. Answer what the AI finds — unresolved threads block merge.
3. A developer approves. Pushing new commits dismisses stale approvals.
4. Click **Squash and merge**.

### Stage 2 — `test` into `main`

5. QA exercises the change on the `test` branch. If it fails, back to step 1.
6. On sign-off, someone runs `gh workflow run promote.yml`. That opens the
   release PR with generated notes — it does not merge anything.
7. All checks re-run against the combined branch. Being individually green is
   not the same as being green together.
8. The **tester** approves.
9. A human clicks **Create a merge commit**. Auto-merge is disabled repo-wide,
   so nothing reaches `main` without that click.

The size and linked-issue gates are waived on the release PR — it aggregates
many already-reviewed changes and references many tickets. Everything else
still applies.

## Running the checks locally

```bash
npm ci
npm run verify   # lint + format + typecheck + coverage + build, same as CI
npm run format   # fix formatting in place
```
