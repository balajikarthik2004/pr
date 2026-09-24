#!/usr/bin/env bash
# Create a PR with deliberately planted defects, to check that each gate fires.
#
#   ./scripts/seed-test-pr.sh <scenario>
#
# Scenarios:
#   bugs       - real correctness + security bugs. CI passes, AI should object.
#   lint       - lint + type errors. `verify` should fail.
#   hygiene    - bad title, empty description, no ticket. Hygiene jobs fail.
#   huge       - 900+ added lines. `size` should fail.
#   clean      - a correct change. Everything green, AI says nothing.
set -euo pipefail
S="${1:-}"
[ -z "$S" ] && { echo "usage: $0 <bugs|lint|hygiene|huge|clean>" >&2; exit 2; }

git checkout dev -q 2>/dev/null || git checkout -qb dev
git pull -q --ff-only origin dev 2>/dev/null || true
# Not "test/...": a branch named "test" exists, and git cannot create
# refs under a name that is already a branch.
BR="seed/${S}-$(date +%s)"
git checkout -qb "$BR"

case "$S" in
bugs)
  cat > src/lib/session.ts <<'TS'
import { createHash } from 'node:crypto';

export interface Session {
  userId: string;
  token: string;
  expiresAt: number;
}

const sessions: Session[] = [];

/** Look up a session by token. */
export function findSession(token: string): Session | undefined {
  // BUG (security): timing-unsafe comparison of a secret.
  return sessions.find((s) => s.token === token);
}

/** Drop every expired session. */
export function pruneExpired(now: number): number {
  let removed = 0;
  // BUG (correctness): mutating the array while iterating it by index
  // skips the element after each removal.
  for (let i = 0; i < sessions.length; i++) {
    if (sessions[i]!.expiresAt <= now) {
      sessions.splice(i, 1);
      removed++;
    }
  }
  return removed;
}

/** Hash a password for storage. */
export function hashPassword(plain: string): string {
  // BUG (security): unsalted MD5.
  return createHash('md5').update(plain).digest('hex');
}

/** Fetch display names for a list of user ids. */
export async function loadNames(ids: readonly string[]): Promise<string[]> {
  const names: string[] = [];
  // BUG (performance): N+1 sequential network calls in a loop.
  for (const id of ids) {
    const res = await fetch(`https://example.invalid/users/${id}`);
    const body = (await res.json()) as { name: string };
    names.push(body.name);
  }
  return names;
}
TS
  # Tests that cover the happy path only - exactly how buggy PRs pass CI.
  cat > test/session.test.ts <<'TS'
import { describe, expect, it } from 'vitest';
import { findSession, hashPassword, pruneExpired } from '../src/lib/session.js';

describe('session helpers', () => {
  it('returns undefined for an unknown token', () => {
    expect(findSession('nope')).toBeUndefined();
  });

  it('prunes nothing when the store is empty', () => {
    expect(pruneExpired(Date.now())).toBe(0);
  });

  it('hashes deterministically', () => {
    expect(hashPassword('hunter2')).toBe(hashPassword('hunter2'));
  });
});
TS
  TITLE="feat: add session lookup and pruning helpers"
  ;;
lint)
  printf '\nexport const broken: number = "not a number";\nconsole.log("debug")\nlet unused = 1\n' >> src/index.ts
  TITLE="fix: adjust index exports for downstream consumers"
  ;;
hygiene)
  printf '\n// touch\n' >> src/index.ts
  TITLE="WIP stuff"
  ;;
huge)
  mkdir -p src/generated-ish
  { for i in $(seq 1 950); do echo "export const value${i} = ${i};"; done; } > src/generated-ish/bulk.ts
  TITLE="chore: add generated constant table for lookups"
  ;;
clean)
  cat >> src/lib/pricing.ts <<'TS'

/** Total quantity across all line items. */
export function itemCount(items: readonly LineItem[]): number {
  return items.reduce((n, item) => n + item.quantity, 0);
}
TS
  cat >> test/pricing.test.ts <<'TS'

describe('itemCount', () => {
  it('sums quantities', () => {
    expect(itemCount(cart)).toBe(5);
  });

  it('is 0 for an empty cart', () => {
    expect(itemCount([])).toBe(0);
  });
});
TS
  sed -i "s/  type LineItem,/  itemCount,\n  type LineItem,/" test/pricing.test.ts
  TITLE="feat: add itemCount helper for cart summaries"
  ;;
*) echo "unknown scenario: $S" >&2; exit 2 ;;
esac

git add -A
git commit -qm "$TITLE"
git push -q -u origin "$BR"

if [ "$S" = "hygiene" ]; then
  BODY="too short"
else
  BODY=$(cat <<'MD'
## What

Adds helpers used by the checkout flow.

## Why

Closes #1

## How tested

`npm run verify` locally; new unit tests cover the added branches.

## Risk / rollback

Additive only. Revert the commit to roll back.
MD
)
fi

gh pr create --base dev --head "$BR" --title "$TITLE" --body "$BODY"
echo
echo "Scenario '$S' pushed. Watch it with:  gh pr checks --watch"
