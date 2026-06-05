# Branch: wait-for-background-ops-before-quit

## Purpose

Addresses a long-standing annoyance (tracked upstream at
https://github.com/jesseduffield/lazygit/issues/2805): pressing `q` to quit
lazygit while a background operation (e.g. a push) is in progress silently
kills the operation. The push never completes.

This branch adds a quit dialog that fires when a non-interruptible background
operation is running:

```
Operation in progress
Lazygit will quit once the current operation finishes.

Press <enter> to quit immediately.
```

- If the user does nothing, lazygit auto-quits as soon as the operation
  finishes.
- If the user presses Enter, it quits immediately (same as before).
- If the user presses Escape, the dialog closes and lazygit keeps running.

## What counts as a "blocking" operation

Not every background worker blocks the quit dialog. The branch introduces a
distinction:

- **`c.OnWorker(...)`** — tracked. These are operations where interrupting
  mid-flight would leave things in a bad state (push, pull, rebase, etc.).
  Triggers the dialog.
- **`c.OnInterruptibleWorker(...)`** — untracked. Safe to abandon at any time
  (fetch, branch behind-count loading, spinner animation, autocomplete
  suggestions). Quit is immediate, no dialog.

## Key implementation details

- `Gui.workerCount` (mutex-protected int) tracks in-flight `OnWorker`
  goroutines. Incremented on start, decremented on finish.
- `sync.Cond` (`workerIdle`) is broadcast when the count reaches zero,
  allowing the quit-dialog watcher goroutine to wake instantly rather than
  polling.
- The `cancelled` flag shared between the watcher goroutine and the dialog
  callbacks is an `atomic.Bool` to avoid a data race.

## Status

Working. Manually tested with the scripts below. Not yet submitted upstream —
this is a personal fork branch.

Remaining questions before an upstream PR:
- Whether the upstream maintainers want the `OnInterruptibleWorker` distinction
  at the call site level, or prefer a different API.
- Integration test coverage (lazygit's integration tests drive a real git
  process; a slow-remote test might be feasible).

## Building

```sh
make build       # produces ./lazygit (debug symbols, no optimizations)
make build-dev   # same + embeds commit/date/buildSource, codesigns the binary
make install     # go install (puts binary in $GOPATH/bin)
```

## Manual test scripts

Two shell scripts in `scripts/` set up throwaway repos for manual testing.

### `scripts/setup_slow_fetch_test.sh` — fetch should NOT trigger the dialog

```sh
./scripts/setup_slow_fetch_test.sh [delay_seconds]   # default: 15s
```

Creates:
- A bare remote at `/tmp/lazygit-slow-fetch-remote`
- A local repo at `/tmp/lazygit-fetch-test-repo`
- A `git-upload-pack` wrapper in `/tmp/lazygit-slow-exec` that sleeps before
  running, simulating a slow fetch

Run lazygit with the slow exec path injected:

```sh
GIT_EXEC_PATH=/tmp/lazygit-slow-exec:$(git --exec-path) lazygit -p /tmp/lazygit-fetch-test-repo
```

Press `f` to fetch. While "Fetching..." spins, press `q`.
**Expected**: quits immediately, no dialog (fetch is interruptible).

### `scripts/setup_slow_push_test.sh` — push SHOULD trigger the dialog

```sh
./scripts/setup_slow_push_test.sh [delay_seconds]    # default: 10s
```

Creates:
- A bare remote at `/tmp/lazygit-slow-remote` with a `pre-receive` hook that
  sleeps, simulating a slow push
- A local repo at `/tmp/lazygit-test-repo`

Open lazygit, push to the `slow` remote, then press `q` while the push spinner
is running.
**Expected**: dialog appears — lazygit waits for the push to finish, then
auto-quits.
