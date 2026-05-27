#!/bin/bash
set -e

IMAGE_NAME="${1:-n8n-custom-test}"
CONTAINER_NAME="n8n-startup-check"
MAX_WAIT=90

echo "Running startup and process-user checks for $IMAGE_NAME..."

CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

docker run --rm -d \
  --name "$CONTAINER_NAME" \
  -e PUID="$CURRENT_UID" \
  -e PGID="$CURRENT_GID" \
  -p 5678:5678 \
  "$IMAGE_NAME"

cleanup() {
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for health endpoint
echo "Waiting for n8n health endpoint (up to ${MAX_WAIT}s)..."
ELAPSED=0
until curl -sf "http://localhost:5678/healthz" > /dev/null 2>&1; do
  if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
    echo "FAILURE: n8n did not respond within ${MAX_WAIT}s."
    docker logs "$CONTAINER_NAME"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
echo "SUCCESS: n8n is responding at http://localhost:5678/healthz"

# Verify the n8n process is running as the expected UID, not root
echo "Checking process user..."
N8N_PID=$(docker exec "$CONTAINER_NAME" pgrep -f "n8n" | head -n 1)
if [ -z "$N8N_PID" ]; then
  echo "FAILURE: Could not find n8n process."
  docker logs "$CONTAINER_NAME"
  exit 1
fi

PROC_UID=$(docker exec "$CONTAINER_NAME" sh -c "awk '/^Uid:/{print \$2}' /proc/$N8N_PID/status")
echo "n8n process UID: $PROC_UID (Expected: $CURRENT_UID)"

if [ "$PROC_UID" != "$CURRENT_UID" ]; then
  echo "FAILURE: n8n is running as UID $PROC_UID, expected $CURRENT_UID."
  docker logs "$CONTAINER_NAME"
  exit 1
fi
echo "SUCCESS: n8n is running as expected UID $PROC_UID."

echo "Done."
