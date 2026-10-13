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

guest 'uname -srm' \
  > "$RESULTS_DIR/uname.txt"

guest 'systemctl is-system-running || true' \
  > "$RESULTS_DIR/system-state.txt"

guest 'cat /usr/share/butrelinux/image-info.json' \
  > "$IMAGE_INFO"

OS_NAME="$(
  sed -n 's/^PRETTY_NAME=//p' "$RESULTS_DIR/os-release.txt" |
    head -n 1 |
    tr -d '"'
)"

KERNEL="$(cat "$RESULTS_DIR/uname.txt")"
SYSTEM_STATE="$(cat "$RESULTS_DIR/system-state.txt")"

PLASMA_VERSION="$(
  guest 'plasmashell --version 2>/dev/null || rpm -q plasma-workspace 2>/dev/null || true' \
    2>/dev/null || true
)"

PLASMA_VERSION="${PLASMA_VERSION:-Not detected}"

printf '%s\n' "$PLASMA_VERSION" \
  > "$RESULTS_DIR/plasma-version.txt"

NVIDIA_VERSION="Not applicable"

if grep -qi nvidia "$IMAGE_INFO"; then
  NVIDIA_VERSION="$(
    guest 'rpm -q --qf "%{VERSION}-%{RELEASE}\n" akmod-nvidia kmod-nvidia 2>/dev/null; rpm -q --qf "%{VERSION}-%{RELEASE}\n" xorg-x11-drv-nvidia 2>/dev/null; modinfo -F version nvidia 2>/dev/null' \
      2>/dev/null |
      sed '/^$/d' |
      sort -u |
      paste -sd ', ' - || true
  )"

  NVIDIA_VERSION="${NVIDIA_VERSION:-Installed driver not detected}"

  if guest 'nvidia-smi --query-gpu=driver_version --format=csv,noheader' \
      > "$RESULTS_DIR/nvidia-smi.txt" 2>/dev/null; then
    NVIDIA_GPU_STATUS="GPU detected"
  else
    NVIDIA_GPU_STATUS="No GPU detected in VM"
    rm -f "$RESULTS_DIR/nvidia-smi.txt"
  fi
fi

{
  echo "# Image test report"
  echo
  echo "| Property | Value |"
  echo "|---|---|"
  printf '| OS | %s |\n' "${OS_NAME:-Unknown}"
  printf '| Kernel | `%s` |\n' "$KERNEL"
  printf '| systemd | %s |\n' "$SYSTEM_STATE"
  printf '| KDE Plasma | %s |\n' "$PLASMA_VERSION"

  if grep -qi nvidia "$IMAGE_INFO"; then
    printf '| NVIDIA driver | %s |\n' "$NVIDIA_VERSION"
    printf '| NVIDIA GPU | %s |\n' "$NVIDIA_GPU_STATUS"
  fi
} > "$REPORT"

echo
echo "Report written to $REPORT"
cat "$REPORT"
