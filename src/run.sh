#!/bin/bash

set -eu

# Source environment configuration
source /env.sh

# Configure S3 signature version if needed
if [ "$S3_S3V4" = "yes" ]; then
  aws configure set default.s3.signature_version s3v4
fi

# If no schedule is provided, run backup once, otherwise schedule it
if [ -z "$SCHEDULE" ]; then
  echo "Running one-time backup..."
  bash /backup.sh
else
  echo "Scheduling backup: $SCHEDULE"
  exec go-cron "$SCHEDULE" /bin/bash /backup.sh
fi