# Contributing

These rules are enforced by CI. Nothing here relies on someone remembering it.

## Branching

- Branch off `main`. Name it `feat/…`, `fix/…`, `chore/…`, or `test/…`.
- Never push to `main`. It is protected.
- Rebase onto `main` before requesting review; merges must be fast-forwardable.

## Pull request rules

| Rule | Limit | Enforced by |
|---|---|---|
| Title format | Conventional Commits, subject 10–72 chars, lowercase, no trailing period | `title` |
| Description | All four template sections, filled in, ≥80 chars | `description` |
| Linked work | `#123` or `ABC-456` in title or body | `linked-issue` |
| Not a draft, no WIP marker | — | `not-wip` |
| Size | ≤800 changed lines, ≤50 files (lockfiles and generated excluded) | `size` |
| Lint / types / tests / build | all pass | `verify` |
| Coverage | lines ≥80%, branches ≥70% | `verify` |
| Secrets, SAST, vulnerable deps | no high-severity findings | `security` |

Over the size limit for a genuine reason? Add the `large-pr` label **and** justify it
in the description. The label waives the check and leaves an audit trail.

## The AI reviewer

Every non-draft PR gets an automated review from Claude. It posts inline comments
tagged `[blocking]`, `[should-fix]`, or `[nit]`, plus one summary comment.

**It does not gate the merge.** It is a reviewer, not a judge. But:

- Every one of its comments must be resolved or replied to — "Require conversation
  resolution" is on, so unanswered threads block the merge button.
- Disagreeing is fine and expected. Reply saying why, then resolve.
- A human still reviews the code. The AI catches a class of thing humans skim past;
  it does not catch intent, architecture, or whether the change should exist.

## Review and merge

1. Open the PR. CI and the AI reviewer start automatically.
2. Fix what CI finds. Answer what the AI finds.
3. A human reviewer approves. Pushing new commits dismisses stale approvals.
4. You click **Squash and merge**. There is no auto-merge — the last step is a
   person deciding to ship.

## Running the checks locally

```bash
npm ci
npm run verify   # lint + typecheck + coverage + build, same as CI
```
