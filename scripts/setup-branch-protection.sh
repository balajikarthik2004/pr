#!/usr/bin/env bash
# Apply branch protection to main.
#
#   ./scripts/setup-branch-protection.sh <owner/repo> [sandbox|prod]
#
# sandbox : 0 required approvals  (you cannot approve your own PR on a
#           personal repo, so 1 would block every test PR forever)
# prod    : 1 required approval + CODEOWNERS review + admin enforcement
#
# Requires: gh auth login  with the `repo` scope.
set -euo pipefail

REPO="${1:-}"
MODE="${2:-sandbox}"

if [ -z "$REPO" ]; then
  echo "usage: $0 <owner/repo> [sandbox|prod]" >&2
  exit 2
fi

case "$MODE" in
  sandbox) APPROVALS=0; CODEOWNERS=false; ADMINS=false; LAST_PUSH=false ;;
  prod)    APPROVALS=1; CODEOWNERS=true;  ADMINS=true;  LAST_PUSH=true  ;;
  *) echo "mode must be 'sandbox' or 'prod'" >&2; exit 2 ;;
esac

echo "Applying '$MODE' protection to $REPO:main"
echo

# The names here must match the job `name:` values in the workflows.
# The AI reviewer is deliberately absent - it advises, it does not block.
PAYLOAD=$(cat <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "verify",
      "security",
      "analyze",
      "title",
      "description",
      "linked-issue",
      "not-wip",
      "size"
    ]
  },
  "enforce_admins": ${ADMINS},
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": ${CODEOWNERS},
    "required_approving_review_count": ${APPROVALS},
    "require_last_push_approval": ${LAST_PUSH}
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
)

if ! echo "$PAYLOAD" | gh api -X PUT "repos/${REPO}/branches/main/protection" --input - >/dev/null; then
  echo
  echo "FAILED. The usual causes:" >&2
  echo "  403 Upgrade   : branch protection on a PRIVATE personal repo needs GitHub Pro." >&2
  echo "                  Either make the repo public, upgrade, or test protection in the org." >&2
  echo "  404           : wrong owner/repo, or 'main' does not exist yet (push a commit first)." >&2
  echo "  403 scope     : run 'gh auth refresh -s repo'" >&2
  exit 1
fi

# Squash-only merges, no auto-merge: the merge stays a deliberate human click.
gh api -X PATCH "repos/${REPO}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F allow_auto_merge=false \
  -F delete_branch_on_merge=true \
  -F squash_merge_commit_title=PR_TITLE \
  -F squash_merge_commit_message=PR_BODY >/dev/null

echo "Done. Current protection:"
gh api "repos/${REPO}/branches/main/protection" \
  --jq '{
    checks: .required_status_checks.contexts,
    strict: .required_status_checks.strict,
    approvals: .required_pull_request_reviews.required_approving_review_count,
    codeowners: .required_pull_request_reviews.require_code_owner_reviews,
    dismiss_stale: .required_pull_request_reviews.dismiss_stale_reviews,
    conversations: .required_conversation_resolution.enabled,
    linear: .required_linear_history.enabled,
    force_push: .allow_force_pushes.enabled,
    admins: .enforce_admins.enabled
  }'
