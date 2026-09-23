#!/bin/sh
set -eu

CACHEFS=/usr/bin/cachefs
WORK=/work
SOURCE="$WORK/source"
MANIFEST="$WORK/source.manifest"
MOUNT_A="$WORK/mount-a"
MOUNT_B="$WORK/mount-b"
LOG_A="$WORK/node-a.log"
LOG_B="$WORK/node-b.log"
SERF_GROUP="${SERF_GROUP:-cachefs-ae-loopback}"
PID_A=""
PID_B=""

mounted() {
  grep -qs " $1 " /proc/mounts
}

cleanup() {
  for mount in "$MOUNT_A" "$MOUNT_B"; do
    if mounted "$mount"; then
      fusermount -uz "$mount" 2>/dev/null || umount -l "$mount" 2>/dev/null || true
    fi
  done
  for pid in "$PID_A" "$PID_B"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}

trap 'cleanup' EXIT INT TERM

wait_mount() {
  mount=$1
  log=$2
  attempt=0
  while [ "$attempt" -lt 30 ]; do
    mounted "$mount" && return 0
    sleep 1
    attempt=$((attempt + 1))
  done
  tail -n 100 "$log" >&2 || true
  echo "CacheFS did not mount $mount" >&2
  exit 1
}

metric() {
  awk -v key="$1" '$1 == key { print $2; found=1; exit } END { if (!found) exit 1 }' "$2"
}

mkdir -p "$MOUNT_A" "$MOUNT_B"

"$CACHEFS" cache \
  --cache-nic lo --cache-port 17888 --serf-port 17999 \
  --serf-node-name cachefs-ae-loopback-a --serf-group "$SERF_GROUP" \
  --liveness 127.0.0.1:19555 --metrics 127.0.0.1:19678 \
  --serf-leave-delay 0 --free-space-ratio 0.01 \
  --source-dir "$SOURCE" --cache-dir memory --cache-size 64 \
  --transport tcp --checksum crc32 cachefs "$MOUNT_A" >"$LOG_A" 2>&1 &
PID_A=$!
wait_mount "$MOUNT_A" "$LOG_A"

"$CACHEFS" cache \
  --cache-nic lo --cache-port 17887 --serf-port 17998 \
  --serf-node-name cachefs-ae-loopback-b --serf-group "$SERF_GROUP" \
  --serf-join 127.0.0.1:17999 --liveness 127.0.0.1:19556 --metrics 127.0.0.1:19679 \
  --serf-leave-delay 0 --free-space-ratio 0.01 \
  --source-dir "$SOURCE" --cache-dir memory --cache-size 64 \
  --transport tcp --checksum crc32 cachefs "$MOUNT_B" >"$LOG_B" 2>&1 &
PID_B=$!
wait_mount "$MOUNT_B" "$LOG_B"

(cd "$MOUNT_A" && sha256sum -c "$MANIFEST")
SOURCE_A=$(metric cachefs_source_reads "$MOUNT_A/.stats")
REMOTE_A=$(metric cachefs_remote_hits "$MOUNT_A/.stats")
[ "$SOURCE_A" -gt 0 ] || { echo "node A source reads were not positive" >&2; exit 1; }
[ "$REMOTE_A" -eq 0 ] || { echo "node A unexpectedly had peer hits" >&2; exit 1; }

sleep 5
(cd "$MOUNT_B" && sha256sum -c "$MANIFEST")
REMOTE_B=$(metric cachefs_remote_hits "$MOUNT_B/.stats")
SOURCE_B=$(metric cachefs_source_reads "$MOUNT_B/.stats")
CHECKSUM_B=$(metric cachefs_remote_checksum_error_count "$MOUNT_B/.stats")
[ "$REMOTE_B" -gt 0 ] || { echo "node B peer hits were not positive" >&2; exit 1; }
[ "$SOURCE_B" -eq 0 ] || { echo "node B unexpectedly read from source" >&2; exit 1; }
[ "$CHECKSUM_B" -eq 0 ] || { echo "node B checksum errors were nonzero" >&2; exit 1; }

cp "$MOUNT_A/.stats" "$WORK/node-a.stats"
cp "$MOUNT_B/.stats" "$WORK/node-b.stats"
printf '{\n  "format": 1,\n  "scenario": "loopback-two-node-peer-read",\n  "image_transport": "tcp",\n  "node_a": {"source_reads": %s, "remote_hits": %s},\n  "node_b": {"source_reads": %s, "remote_hits": %s, "checksum_errors": %s}\n}\n' \
  "$SOURCE_A" "$REMOTE_A" "$SOURCE_B" "$REMOTE_B" "$CHECKSUM_B" > "$WORK/result.json"
printf 'PASS loopback source fill and peer read\n'
