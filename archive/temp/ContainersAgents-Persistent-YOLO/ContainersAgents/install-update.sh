#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CONTAINERS_AGENTS_TARGET:-/home/jose/Scripts/Development/ContainersAgents}"

if [[ "${1:-}" != "--yes" ]]; then
  cat >&2 <<EOF2
This updates:
  $TARGET_DIR
from:
  $SOURCE_DIR

It preserves TARGET_DIR/state and TARGET_DIR/projects, overwrites controller
files, and removes legacy managed containers whose names are not the new fixed
containers. Legacy container writable layers may contain manually installed
packages. Rerun with --yes after reviewing this message.
EOF2
  exit 2
fi

mkdir -p "$TARGET_DIR"

backup="$HOME/ContainersAgents-controller-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
if [[ -d "$TARGET_DIR" ]]; then
  tar -czf "$backup" \
    --exclude='./state' \
    --exclude='./projects' \
    --exclude='./*.tar.gz' \
    --exclude='./*.sha256' \
    -C "$TARGET_DIR" . 2>/dev/null || true
  echo "Controller-file backup: $backup"
fi

if command -v podman >/dev/null 2>&1; then
  mapfile -t legacy < <(podman ps --all --format '{{.Names}}' \
    --filter 'label=io.jose.containers-agents.managed=true' \
    | grep -Ev '^(containers-agent-debian|containers-agent-fedora)$' || true)
  if ((${#legacy[@]})); then
    echo "Removing legacy managed containers: ${legacy[*]}"
    podman rm --force --time 10 "${legacy[@]}" >/dev/null
  fi
fi

(cd "$SOURCE_DIR" && tar -cf - --exclude='./state' --exclude='./projects' .) \
  | (cd "$TARGET_DIR" && tar -xf -)

mkdir -p \
  "$TARGET_DIR/state/debian/home" \
  "$TARGET_DIR/state/fedora/home" \
  "$TARGET_DIR/projects/container-agent-test"

touch \
  "$TARGET_DIR/state/debian/home/.gitkeep" \
  "$TARGET_DIR/state/fedora/home/.gitkeep" \
  "$TARGET_DIR/projects/container-agent-test/.gitkeep"

chmod +x \
  "$TARGET_DIR/agentctl" \
  "$TARGET_DIR/agents.sh" \
  "$TARGET_DIR/install-update.sh" \
  "$TARGET_DIR/extras/install-debian.sh" \
  "$TARGET_DIR/extras/install-fedora.sh"

echo "Update installed at $TARGET_DIR"
echo "Next: cd '$TARGET_DIR' && ./agents.sh doctor && ./agents.sh build all"
