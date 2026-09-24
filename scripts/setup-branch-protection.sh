#!/usr/bin/env bash
# Protect all three branches in the feature -> dev -> test -> main flow.
#
#   ./scripts/setup-branch-protection.sh <owner/repo> [solo|team|prod]
#
# solo : 0 required approvals. Only for a single-account repo, where you
#        cannot approve your own PR and 1 would deadlock every PR.
# team : 1 approval on every hop. Use this when you have a second account
#        added as a collaborator - it exercises the real approval gates.
# prod : same as team, plus CODEOWNERS review and admin enforcement.
#
# Requires: gh auth login   (scope: repo)
set -euo pipefail

REPO="${1:-}"
MODE="${2:-team}"
[ -z "$REPO" ] && { echo "usage: $0 <owner/repo> [solo|team|prod]" >&2; exit 2; }

case "$MODE" in
  solo) APPROVALS=0; CODEOWNERS=false; ADMINS=false; LAST_PUSH=false ;;
  team) APPROVALS=1; CODEOWNERS=false; ADMINS=false; LAST_PUSH=true  ;;
  prod) APPROVALS=1; CODEOWNERS=true;  ADMINS=true;  LAST_PUSH=true  ;;
  *) echo "mode must be 'solo', 'team' or 'prod'" >&2; exit 2 ;;
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

# Create dev and test from main if they do not exist yet.
MAIN_SHA=$(gh api "repos/${REPO}/git/ref/heads/main" --jq .object.sha)
for b in dev test; do
  if ! gh api "repos/${REPO}/branches/${b}" >/dev/null 2>&1; then
    echo "Creating '${b}' from main..."
    gh api -X POST "repos/${REPO}/git/refs"       -f ref="refs/heads/${b}" -f sha="$MAIN_SHA" >/dev/null
  fi
done

echo "Applying '$MODE' protection to $REPO"

# dev: entry point. Feature branches squash-merge in, so linear history holds.
if ! protect dev "$APPROVALS" false true; then
  echo "FAILED on 'dev'. Common causes:" >&2
  echo "  403 Upgrade : branch protection on a PRIVATE personal repo needs GitHub Pro." >&2
  echo "                Make the repo public, upgrade, or test protection in the org." >&2
  echo "  403 scope   : gh auth refresh -s repo" >&2
  exit 1
fi

# test and main receive MERGE COMMITS from the promotion PRs, so
# required_linear_history must be false or the merge is rejected.
protect test "$APPROVALS" false false
protect main "$APPROVALS" "$CODEOWNERS" false

# Both merge styles enabled - you pick per PR:
#   feature -> dev  : Squash and merge      (one tidy commit per change)
#   dev     -> test : Create a merge commit
#   test    -> main : Create a merge commit
# Squashing a promotion would make the two branches permanently diverge.
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
for b in dev test main; do
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
echo "Point new PRs at 'dev' by making it the default branch:"
echo "  gh repo edit ${REPO} --default-branch dev"
