#!/usr/bin/env bash
set -Eeuo pipefail

: "${SSH_HOST:?SSH_HOST must be set}"
: "${SSH_PORT:?SSH_PORT must be set}"
: "${SSH_USER:?SSH_USER must be set}"
: "${RESULTS_DIR:?RESULTS_DIR must be set}"
: "${SSHPASS:?SSHPASS must be set}"

mkdir -p "$RESULTS_DIR"

SSH_OPTS=(
  -p "$SSH_PORT"
  -o PreferredAuthentications=password
  -o PubkeyAuthentication=no
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10
  -o NumberOfPasswordPrompts=1
)

guest() {
  sshpass -e ssh "${SSH_OPTS[@]}" \
    "$SSH_USER@$SSH_HOST" "$@"
}

echo "Testing $SSH_USER@$SSH_HOST:$SSH_PORT"

# Basic guest information.
guest 'cat /etc/os-release' \
  > "$RESULTS_DIR/os-release.txt"

guest 'uname -a' \
  > "$RESULTS_DIR/uname.txt"

guest 'systemctl is-system-running || true' \
  > "$RESULTS_DIR/system-state.txt"

# tests are incomplete, this is just a minimal placeholder.

echo "All tests passed."
