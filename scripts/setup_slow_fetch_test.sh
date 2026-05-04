#!/bin/sh
# Sets up a test repo in /tmp with a slow remote for testing the
# "fetch should not block quit" behavior.
#
# Usage: ./setup_slow_fetch_test.sh [delay_seconds]
#
# Then build lazygit, cd to /tmp/lazygit-fetch-test-repo, and run:
#   GIT_EXEC_PATH=/tmp/lazygit-slow-exec:$(git --exec-path) lazygit
#
# Press f to fetch. While "Fetching..." spins, press q.
# You should quit IMMEDIATELY — no dialog.

set -e

DELAY=${1:-15}
REMOTE=/tmp/lazygit-slow-fetch-remote
REPO=/tmp/lazygit-fetch-test-repo
EXEC_DIR=/tmp/lazygit-slow-exec

echo "Setting up slow git-upload-pack wrapper (delay: ${DELAY}s)..."
mkdir -p "$EXEC_DIR"
printf '#!/bin/sh\necho "slow fetch: sleeping %s seconds..." >&2\nsleep %s\nexec "$(git --exec-path)/git-upload-pack" "$@"\n' "$DELAY" "$DELAY" > "$EXEC_DIR/git-upload-pack"
chmod +x "$EXEC_DIR/git-upload-pack"

echo "Setting up bare remote at $REMOTE..."
rm -rf "$REMOTE"
git init --bare "$REMOTE"
TMPWORK=$(mktemp -d)
git clone "$REMOTE" "$TMPWORK/work" --quiet
git -C "$TMPWORK/work" commit --allow-empty -m "remote initial commit"
git -C "$TMPWORK/work" push origin HEAD --quiet
rm -rf "$TMPWORK"

echo "Setting up test repo at $REPO..."
rm -rf "$REPO"
git init "$REPO"
git -C "$REPO" commit --allow-empty -m "initial commit"
git -C "$REPO" remote add slow "$REMOTE"

echo ""
echo "Done. Build lazygit, then:"
echo ""
echo "  GIT_EXEC_PATH=$EXEC_DIR:\$(git --exec-path) lazygit -p $REPO"
echo ""
echo "Press f to fetch. While 'Fetching...' spins, press q."
echo "Expected: quit immediately, no dialog."
echo "Bug:      dialog appears asking to wait."
