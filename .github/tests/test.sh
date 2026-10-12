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

REPORT="$RESULTS_DIR/report.md"
IMAGE_INFO="$RESULTS_DIR/image-info.json"

echo "Testing $SSH_USER@$SSH_HOST:$SSH_PORT"

guest 'cat /etc/os-release' \
  > "$RESULTS_DIR/os-release.txt"

guest 'uname -a' \
  > "$RESULTS_DIR/uname.txt"

guest 'systemctl is-system-running || true' \
  > "$RESULTS_DIR/system-state.txt"

guest 'cat /usr/share/butrelinux/image-info.json' \
  > "$IMAGE_INFO"

OS_NAME="$(
  . /dev/null 2>/dev/null || true
  sed -n 's/^PRETTY_NAME=//p' "$RESULTS_DIR/os-release.txt" |
    head -n 1 |
    tr -d '"'
)"

KERNEL="$(cat "$RESULTS_DIR/uname.txt")"
SYSTEM_STATE="$(cat "$RESULTS_DIR/system-state.txt")"

{
  echo "# Image test report"
  echo
  echo "## System information"
  echo
  echo "| Property | Value |"
  echo "|---|---|"
  printf '| OS | %s |\n' "${OS_NAME:-Unknown}"
  printf '| Kernel | %s |\n' "$KERNEL"
  printf '| systemd | %s |\n' "$SYSTEM_STATE"
} > "$REPORT"

PLASMA_VERSION="$(
  guest 'plasmashell --version 2>/dev/null || rpm -q plasma-workspace 2>/dev/null || true' \
    2>/dev/null || true
)"

if [[ -n "$PLASMA_VERSION" ]]; then
  printf '%s\n' "$PLASMA_VERSION" > "$RESULTS_DIR/plasma-version.txt"
  {
    echo
    echo "## KDE Plasma"
    echo
    printf '%s\n' "$PLASMA_VERSION"
  } >> "$REPORT"
else
  {
    echo
    echo "## KDE Plasma"
    echo
    echo "No Plasma version detected."
  } >> "$REPORT"
fi

if grep -qi nvidia "$IMAGE_INFO"; then
  NVIDIA_VERSION="$(
    guest 'nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || modinfo -F version nvidia 2>/dev/null || rpm -qa | grep -Ei "nvidia.*(driver|kmod)|akmod-nvidia" || true' \
      2>/dev/null || true
  )"

  printf '%s\n' "${NVIDIA_VERSION:-Not detected in the running VM}" \
    > "$RESULTS_DIR/nvidia-version.txt"

  {
    echo
    echo "## NVIDIA"
    echo
    printf '%s\n' "${NVIDIA_VERSION:-Not detected in the running VM}"
  } >> "$REPORT"
else
  echo "NVIDIA: not applicable"
fi

guest 'cat /etc/os-release' >/dev/null
guest 'uname -a' >/dev/null

echo
echo "Report written to $REPORT"
cat "$REPORT"
