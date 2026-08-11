#!/bin/sh
# Sets up a test repo in /tmp with a slow remote for testing the
# "wait for background ops before quit" behavior.
#
# Usage: ./scripts/setup_slow_push_test.sh [delay_seconds]
#
# Then open lazygit in /tmp/lazygit-test-repo, push to the 'slow' remote,
# and press q while the push is in progress.

set -e

DELAY=${1:-10}
REMOTE=/tmp/lazygit-slow-remote
REPO=/tmp/lazygit-test-repo

echo "Setting up slow remote at $REMOTE (pre-receive delay: ${DELAY}s)..."
rm -rf "$REMOTE"
git init --bare "$REMOTE"
printf '#!/bin/sh\necho "Slow remote: sleeping %s seconds..."\nsleep %s\n' "$DELAY" "$DELAY" > "$REMOTE/hooks/pre-receive"
chmod +x "$REMOTE/hooks/pre-receive"

echo "Setting up test repo at $REPO..."
rm -rf "$REPO"
git init "$REPO"
git -C "$REPO" commit --allow-empty -m "initial commit"
git -C "$REPO" remote add slow "$REMOTE"

echo ""
echo "Done. To test:"
echo "  1. cd $REPO"
echo "  2. Open lazygit (e.g. ~/bin/lazygit)"
echo "  3. Push to the 'slow' remote"
echo "  4. Press q while the push spinner is running"
echo "  5. You should see a prompt to wait or quit anyway"
