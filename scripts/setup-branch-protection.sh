#!/usr/bin/env bash
# Protect both branches in the feature -> test -> main flow.
#
#   ./scripts/setup-branch-protection.sh <owner/repo> [sandbox|prod]
#
# sandbox : 0 required approvals. You cannot approve your own PR on a personal
#           repo, so 1 would deadlock every test PR. Everything else is real.
# prod    : test needs 1 dev approval; main needs 1 tester approval with
#           CODEOWNERS review and admin enforcement.
#
# Requires: gh auth login   (scope: repo)
set -euo pipefail

REPO="${1:-}"
MODE="${2:-sandbox}"
[ -z "$REPO" ] && { echo "usage: $0 <owner/repo> [sandbox|prod]" >&2; exit 2; }

case "$MODE" in
  sandbox) TEST_APPROVALS=0; MAIN_APPROVALS=0; CODEOWNERS=false; ADMINS=false; LAST_PUSH=false ;;
  prod)    TEST_APPROVALS=1; MAIN_APPROVALS=1; CODEOWNERS=true;  ADMINS=true;  LAST_PUSH=true  ;;
  *) echo "mode must be 'sandbox' or 'prod'" >&2; exit 2 ;;
esac

# Job names from the workflows. The AI reviewer is deliberately absent:
# it comments, it does not gate.
CHECKS='["verify","security","analyze","title","description","linked-issue","not-wip","size"]'

protect() {
  local branch="$1" approvals="$2" codeowners="$3" linear="$4"
  echo "  -> $branch  (approvals=$approvals codeowners=$codeowners linear_history=$linear)"
  cat <<JSON | gh api -X PUT "repos/${REPO}/branches/${branch}/protection" --input - >/dev/null
{
  "required_status_checks": { "strict": true, "contexts": ${CHECKS} },
  "enforce_admins": ${ADMINS},
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": ${codeowners},
    "required_approving_review_count": ${approvals},
    "require_last_push_approval": ${LAST_PUSH}
  },
  "restrictions": null,
  "required_linear_history": ${linear},
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
}

# Create test from main if it does not exist yet.
if ! gh api "repos/${REPO}/branches/test" >/dev/null 2>&1; then
  echo "Creating 'test' branch from main..."
  SHA=$(gh api "repos/${REPO}/git/ref/heads/main" --jq .object.sha)
  gh api -X POST "repos/${REPO}/git/refs" -f ref=refs/heads/test -f sha="$SHA" >/dev/null
fi

echo "Applying '$MODE' protection to $REPO"

# test: squash-only, so linear history is enforceable.
if ! protect test "$TEST_APPROVALS" false true; then
  echo "FAILED on 'test'. Common causes:" >&2
  echo "  403 Upgrade : branch protection on a PRIVATE personal repo needs GitHub Pro." >&2
  echo "                Make the repo public, upgrade, or test protection in the org." >&2
  echo "  403 scope   : gh auth refresh -s repo" >&2
  exit 1
fi

# main: linear history MUST be false. The release PR merges with a merge
# commit, and required_linear_history would reject it.
protect main "$MAIN_APPROVALS" "$CODEOWNERS" false

# Both merge styles enabled - you pick per PR:
#   feature -> test : Squash and merge   (one tidy commit per change)
#   test    -> main : Create a merge commit
# Squashing into main as well would make the branches permanently diverge.
# Auto-merge stays off: the last step is always a human clicking merge.
# delete_branch_on_merge does not touch 'test' - protected branches are exempt.
gh api -X PATCH "repos/${REPO}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=true \
  -F allow_rebase_merge=false \
  -F allow_auto_merge=false \
  -F delete_branch_on_merge=true \
  -F squash_merge_commit_title=PR_TITLE \
  -F squash_merge_commit_message=PR_BODY >/dev/null

echo
for b in test main; do
  echo "$b:"
  gh api "repos/${REPO}/branches/${b}/protection" --jq '{
    checks: (.required_status_checks.contexts | length),
    strict: .required_status_checks.strict,
    approvals: .required_pull_request_reviews.required_approving_review_count,
    codeowners: .required_pull_request_reviews.require_code_owner_reviews,
    dismiss_stale: .required_pull_request_reviews.dismiss_stale_reviews,
    conversations: .required_conversation_resolution.enabled,
    linear: .required_linear_history.enabled,
    admins: .enforce_admins.enabled
  }'
done
echo
echo "Default branch is still 'main'. Point new PRs at 'test':"
echo "  gh repo edit ${REPO} --default-branch test    # optional but recommended"
