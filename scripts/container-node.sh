#!/bin/sh
set -eu

: "${NODE_NAME:?NODE_NAME is required}"
: "${CACHE_NIC:?CACHE_NIC is required}"
: "${CACHE_PORT:?CACHE_PORT is required}"
: "${SERF_PORT:?SERF_PORT is required}"
: "${SERF_GROUP:?SERF_GROUP is required}"
: "${LIVENESS_PORT:?LIVENESS_PORT is required}"
: "${METRICS_PORT:?METRICS_PORT is required}"

NODE_MODE="${NODE_MODE:-source}"
CACHE_SIZE_MIB="${CACHE_SIZE_MIB:-64}"
BLOCK_SIZE_MIB="${BLOCK_SIZE_MIB:-4}"
PREFETCH_BLOCKS="${PREFETCH_BLOCKS:-24}"
CACHE_EVICTION="${CACHE_EVICTION:-hash}"
SOURCE_DIR="${SOURCE_DIR:-/work/source}"
SOURCE_PEERMETA="${SOURCE_PEERMETA:-30}"

JOIN_ARGS=""
if [ -n "${SERF_JOIN:-}" ]; then
  JOIN_ARGS="--serf-join ${SERF_JOIN}"
fi

SOURCE_ARGS=""
case "${NODE_MODE}" in
  source)
    SOURCE_ARGS="--source-dir ${SOURCE_DIR}"
    ;;
  source-ready)
    SOURCE_ARGS="--source-dir ${SOURCE_DIR} --sourceless"
    ;;
  sourceless)
    SOURCE_ARGS="--sourceless --source-peermeta ${SOURCE_PEERMETA}"
    ;;
  *)
    echo "Unsupported NODE_MODE: ${NODE_MODE}" >&2
    exit 1
    ;;
esac

SOURCE_ID_ARGS=""
if [ -n "${SOURCE_ID:-}" ]; then
  SOURCE_ID_ARGS="--source-id ${SOURCE_ID}"
fi

# shellcheck disable=SC2086
exec /usr/bin/cachefs cache \
  --cache-nic "$CACHE_NIC" --cache-port "$CACHE_PORT" --serf-port "$SERF_PORT" \
  --serf-node-name "$NODE_NAME" --serf-group "$SERF_GROUP" $JOIN_ARGS \
  --liveness "127.0.0.1:$LIVENESS_PORT" --metrics "127.0.0.1:$METRICS_PORT" \
  --serf-leave-delay 0 --free-space-ratio 0.01 \
  --cache-dir memory --cache-size "$CACHE_SIZE_MIB" --block-size "$BLOCK_SIZE_MIB" \
  --prefetch "$PREFETCH_BLOCKS" --cache-eviction "$CACHE_EVICTION" \
  --transport tcp --checksum crc32 $SOURCE_ID_ARGS $SOURCE_ARGS cachefs /work/mount
