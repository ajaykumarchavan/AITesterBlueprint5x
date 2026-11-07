#!/usr/bin/env bash
# Fetch a Jira issue as JSON.
#
# Usage:
#   ./fetch-jira.sh                        fetches VWO-1 (default)
#   ./fetch-jira.sh <ISSUE-KEY> [outfile]  save JSON to a file instead of stdout
#
# Required environment variables (do NOT hardcode credentials):
#   JIRA_BASE_URL   e.g. https://your-company.atlassian.net
#   JIRA_EMAIL      your Atlassian account email
#   JIRA_API_TOKEN  API token from https://id.atlassian.com/manage-profile/security/api-tokens

set -euo pipefail

# Load credentials from the repo-level .env if present
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source <(tr -d '\r' < "$ENV_FILE")
  set +a
fi

ISSUE_KEY="${1:-VWO-1}"   # defaults to VWO-1
OUTFILE="${2:-}"

for var in JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: environment variable $var is not set." >&2
    exit 1
  fi
done

URL="${JIRA_BASE_URL%/}/rest/api/3/issue/${ISSUE_KEY}"

if [[ -n "$OUTFILE" ]]; then
  HTTP_CODE=$(curl --silent --show-error --request GET \
    --url "$URL" \
    --user "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    --header "Accept: application/json" \
    --output "$OUTFILE" --write-out "%{http_code}")
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  HTTP_CODE=$(curl --silent --show-error --request GET \
    --url "$URL" \
    --user "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    --header "Accept: application/json" \
    --output "$TMP" --write-out "%{http_code}")
fi

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error: Jira returned HTTP $HTTP_CODE for $ISSUE_KEY" >&2
  [[ -n "$OUTFILE" ]] && cat "$OUTFILE" >&2 || cat "$TMP" >&2
  echo >&2
  exit 1
fi

if [[ -n "$OUTFILE" ]]; then
  echo "Saved $ISSUE_KEY to $OUTFILE" >&2
else
  cat "$TMP"
fi
