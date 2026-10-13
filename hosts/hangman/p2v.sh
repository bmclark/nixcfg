#!/usr/bin/env bash
# p2v.sh — one-shot helper for the hangman P2V runbook (docs/runbook-hangman-p2v.md).
# Set env vars, then run steps individually or all at once:
#
#   export SDC_MNT=/run/media/bryan/7748b39d-220e-4e8f-966f-740e8ec18c98
#   export TOWER=bryan@tower
#   export TOWER_PATH=/mnt/user/backups/hangman-p2v
#
#   bash p2v.sh convert        # Phase 1: sdb -> win10.qcow2 on sdc
#   bash p2v.sh check          # Phase 1: verify image
#   bash p2v.sh tower          # Phase 2: rsync to Tower + hash both sides
#   bash p2v.sh all            # convert, check, tower in order
set -euo pipefail

SDC_MNT="${SDC_MNT:?Set SDC_MNT to the sdc mountpoint, e.g. /run/media/bryan/<uuid>}"
TOWER="${TOWER:-bryan@tower}"
TOWER_PATH="${TOWER_PATH:-/mnt/user/backups/hangman-p2v}"
SRC_DISK="${SRC_DISK:-/dev/sdb}"
IMAGE="$SDC_MNT/win10.qcow2"

step() { printf '\n==> %s\n' "$1"; }

convert() {
  step "Converting $SRC_DISK -> $IMAGE (30-90 min)"
  [ -w "$SDC_MNT" ] || { echo "sdc not mounted at $SDC_MNT"; exit 1; }
  df -h "$SDC_MNT"
  sudo qemu-img convert -p -O qcow2 "$SRC_DISK" "$IMAGE"
  sudo chown "$(id -un):" "$IMAGE"
  step "Done: $(ls -lh "$IMAGE")"
}

check() {
  step "Verifying $IMAGE"
  qemu-img check "$IMAGE"
  qemu-img info "$IMAGE"
}

tower() {
  step "rsync (checksummed) -> $TOWER:$TOWER_PATH"
  ssh "$TOWER" "mkdir -p '$TOWER_PATH'"
  rsync -av --checksum --progress "$IMAGE" "$TOWER:$TOWER_PATH/"
  step "Hashing both sides (must match)"
  local_local=$(sha256sum "$IMAGE" | awk '{print $1}')
  local_remote=$(ssh "$TOWER" "sha256sum '$TOWER_PATH/win10.qcow2'" | awk '{print $1}')
  echo "local : $local_local"
  echo "tower : $local_remote"
  if [ "$local_local" = "$local_remote" ]; then
    echo "MATCH — Tower copy verified."
  else
    echo "MISMATCH — do not proceed; re-run 'bash p2v.sh tower'."
    exit 1
  fi
}

case "${1:-}" in
  convert) convert ;;
  check) check ;;
  tower) tower ;;
  all) convert && check && tower ;;
  *)
    echo "usage: bash p2v.sh {convert|check|tower|all}"
    echo "env: SDC_MNT (required), TOWER, TOWER_PATH, SRC_DISK (optional)"
    exit 1
    ;;
esac
