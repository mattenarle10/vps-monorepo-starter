#!/usr/bin/env bash
# Smart path-filter deploy script
# Called by GitHub Actions over SSH after git pull
#
# Env vars (set by calling workflow):
#   PREV_SHA — commit before pull
#   NEW_SHA  — commit after pull
#
# Rules:
#   - packages/* changed → rebuild all apps
#   - apps/<name>/* changed → rebuild that app only
#   - api/* changed → rebuild and restart api only
#   - other changes → skip build

set -euo pipefail

REPO_DIR="/opt/myapp"
BUN="/home/myapp/.bun/bin/bun"
ALL_APPS=(web admin)

cd "$REPO_DIR"

PREV_SHA="${PREV_SHA:-$(git rev-parse HEAD~1)}"
NEW_SHA="${NEW_SHA:-$(git rev-parse HEAD)}"

echo "prev: $PREV_SHA"
echo "new:  $NEW_SHA"

if [[ "$PREV_SHA" == "$NEW_SHA" ]]; then
  echo "no new commits, exiting"
  exit 0
fi

CHANGED=$(git diff --name-only "$PREV_SHA" "$NEW_SHA")
echo "changed files:"
echo "$CHANGED" | sed 's/^/  /'

# Rebuild API if api/* changed
if echo "$CHANGED" | grep -qE '^api/'; then
  echo "api changed → rebuilding api"
  sudo -u myapp bash -c "cd $REPO_DIR/api && $BUN install && $BUN run build"
  systemctl restart myapp-api
fi

# Determine which frontend apps to rebuild
if echo "$CHANGED" | grep -qE '^packages/'; then
  APPS=("${ALL_APPS[@]}")
  echo "shared packages changed → rebuilding all apps"
else
  mapfile -t APPS < <(echo "$CHANGED" | grep -oE '^apps/[^/]+/' | cut -d/ -f2 | sort -u)
fi

if [[ ${#APPS[@]} -eq 0 ]]; then
  echo "no app changes → skipping frontend build"
  exit 0
fi

echo "rebuilding: ${APPS[*]}"
for app in "${APPS[@]}"; do
  echo "building $app..."
  sudo -u myapp bash -c "cd $REPO_DIR/apps/$app && $BUN run build"
  systemctl restart "myapp-$app"
done

echo "deploy done"
