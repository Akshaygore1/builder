#!/bin/bash
# log-streamer.sh
# Streams build log lines to the VPS webhook endpoint
#
# Usage: ./log-streamer.sh <phase> <message>
# Environment variables: DEPLOYMENT_ID, CALLBACK_URL, WEBHOOK_SECRET

PHASE="$1"
MESSAGE="$2"

# Validate required env vars
if [ -z "$DEPLOYMENT_ID" ] || [ -z "$CALLBACK_URL" ] || [ -z "$WEBHOOK_SECRET" ]; then
  echo "[log-streamer] Missing required environment variables" >&2
  exit 1
fi

# Global sequence counter file
SEQ_FILE="/tmp/log-seq-${DEPLOYMENT_ID}"
if [ ! -f "$SEQ_FILE" ]; then
  echo "0" > "$SEQ_FILE"
fi

# Increment and read sequence
SEQ=$(( $(cat "$SEQ_FILE") + 1 ))
echo "$SEQ" > "$SEQ_FILE"

# Determine log level from message content
LEVEL="info"
if echo "$MESSAGE" | grep -qi "warn\|warning"; then
  LEVEL="warn"
elif echo "$MESSAGE" | grep -qi "error\|ERR!\|fatal\|FAIL"; then
  LEVEL="error"
fi

# If phase is "failed", level is always error
if [ "$PHASE" = "failed" ]; then
  LEVEL="error"
fi

# Send log line to VPS
# Use --max-time to avoid hanging if VPS is unreachable
curl -s --max-time 5 \
  -X POST "${CALLBACK_URL}/api/webhooks/build-log" \
  -H "Content-Type: application/json" \
  -d "{
    \"secret\": \"${WEBHOOK_SECRET}\",
    \"deploymentId\": \"${DEPLOYMENT_ID}\",
    \"seq\": ${SEQ},
    \"phase\": \"${PHASE}\",
    \"level\": \"${LEVEL}\",
    \"message\": $(echo "$MESSAGE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
  }" > /dev/null 2>&1

# Always exit 0 so build continues even if log delivery fails
exit 0
