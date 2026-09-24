# Contributing

These rules are enforced by CI. Nothing here relies on someone remembering it.

## Branching

Three long-lived branches:

| Branch | What it is | How code gets in | Merge style |
|---|---|---|---|
| `dev` | Integration. Every change lands here first. | PR from a feature branch, full gate | **Squash** |
| `test` | QA exercises this branch. | Promotion PR from `dev` | **Merge commit** |
| `main` | Production. | Promotion PR from `test` | **Merge commit** |

- Branch off `dev`. Name it `feat/…`, `fix/…`, `chore/…`.
- Never push directly to `dev`, `test` or `main`. All three are protected.
- Rebase onto `dev` before requesting review.
- **Squash only into `dev`.** Promotions use "Create a merge commit". Squashing a
  promotion makes the branches diverge and every later promotion PR shows
  phantom conflicts.

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

Every non-draft PR into `dev` gets an automated review from Claude (Sonnet), run by
`.github/workflows/ai-review.yml`. It posts one summary comment plus up to 10 inline
comments, each tagged `[blocking]`, `[should-fix]` or `[nit]`. What it looks for is
defined in `.github/review-guide.md` — that file is the review policy, and it is
worth editing when the reviewer is wrong.

Promotion PRs (`dev → test`, `test → main`) and docs-only PRs are not reviewed:
every change in a promotion was already reviewed on its way into `dev`.

**It does not gate the merge.** It is a reviewer, not a judge. But:

- Every one of its comments must be resolved or replied to — "Require conversation
  resolution" is on, so unanswered threads block the merge button.
- Every push re-runs the review. To re-run without pushing, open the PR's
  **Checks** tab → `AI Code Review` → **Re-run jobs**.
- Disagreeing is fine and expected. Reply saying why, then resolve.
- A human still reviews the code. The AI catches a class of thing humans skim past;
  it does not catch intent, architecture, or whether the change should exist.

## Review and merge

### Stage 1 — your change into `dev`

1. Open a PR from your feature branch into `dev`. All eight checks and the AI
   reviewer start automatically.
2. Fix what CI finds. Answer what the AI finds — unresolved threads block merge.
3. A developer approves. Pushing new commits dismisses stale approvals.
4. Click **Squash and merge**.

### Stage 2 — `dev` into `test`

5. When the integrated changes are ready for QA, run
   `gh workflow run promote.yml -f hop=dev-to-test`. It opens the promotion PR
   with generated notes — it does not merge anything.
6. Checks re-run against the integrated branch. Individually green is not the
   same as green together.
7. A reviewer approves; someone clicks **Create a merge commit**.

### Stage 3 — `test` into `main`

8. QA exercises the changes on `test`. If anything fails, back to step 1.
9. On sign-off, run `gh workflow run promote.yml -f hop=test-to-main`.
10. Checks re-run again. The **tester** approves.
11. A human clicks **Create a merge commit**. Auto-merge is disabled repo-wide,
    so nothing reaches `main` without that click.

The size and linked-issue gates are waived on promotion PRs — they aggregate
many already-reviewed changes and reference many tickets. Every other gate
still applies.

## Running the checks locally

```bash
npm ci
npm run verify   # lint + format + typecheck + coverage + build, same as CI
npm run format   # fix formatting in place
```
