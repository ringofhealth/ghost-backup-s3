#!/bin/bash

set -eu
set -o pipefail

# Load environment variables
source /env.sh

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")
BACKUP_DIR="/tmp/ghost_backup_${TIMESTAMP}"
mkdir -p $BACKUP_DIR

echo "Creating backup of Ghost blog ($MYSQL_DATABASE database and content)..."

# 1. Create MySQL dump
echo "Backing up MySQL database..."
mysqldump $MYSQL_AUTH_OPTS \
    --single-transaction \
    --quick \
    --lock-tables=false \
    $MYSQLDUMP_EXTRA_OPTS \
    $MYSQL_DATABASE > "$BACKUP_DIR/ghost_database.sql"

# 2. Back up Ghost content
echo "Backing up Ghost content..."
if [ -d "$GHOST_CONTENT_DIR" ] && [ "$(ls -A $GHOST_CONTENT_DIR)" ]; then
    tar -czf "$BACKUP_DIR/ghost_content.tar.gz" -C $GHOST_CONTENT_DIR .
else
    echo "Warning: Ghost content directory is empty or not mounted"
    # Create an empty archive to maintain consistency
    mkdir -p /tmp/empty
    tar -czf "$BACKUP_DIR/ghost_content.tar.gz" -C /tmp/empty .
    rm -rf /tmp/empty
fi

# 3. Create metadata file with backup info
cat > "$BACKUP_DIR/backup_info.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "database": "$MYSQL_DATABASE",
  "hostname": "$MYSQL_HOST",
  "version": "1.0.0"
}
EOF

# 4. Create final archive
BACKUP_FILENAME="${MYSQL_DATABASE}_${TIMESTAMP}.tar.gz"
tar -czf "/tmp/$BACKUP_FILENAME" -C $BACKUP_DIR .

# 5. Encrypt backup if passphrase is provided
if [ -n "${PASSPHRASE:-}" ]; then
  echo "Encrypting backup..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" "/tmp/$BACKUP_FILENAME"
  rm "/tmp/$BACKUP_FILENAME"
  BACKUP_FILENAME="${BACKUP_FILENAME}.gpg"
fi

# 6. Upload to S3
S3_URI="s3://${S3_BUCKET}/${S3_PREFIX}/${BACKUP_FILENAME}"
echo "Uploading backup to $S3_URI..."
aws $aws_args s3 cp "/tmp/$BACKUP_FILENAME" "$S3_URI"

# 7. Clean up temporary files
rm -rf $BACKUP_DIR
rm -f "/tmp/$BACKUP_FILENAME"

echo "Backup complete."

# 8. Remove old backups if retention period is set
if [ -n "${BACKUP_KEEP_DAYS:-}" ]; then
  SEC=$((86400*BACKUP_KEEP_DAYS))
  DATE_TO_REMOVE=$(date -d "@$(($(date +%s) - SEC))" +%Y-%m-%d)
  BACKUPS_QUERY="Contents[?LastModified<='${DATE_TO_REMOVE} 00:00:00'].{Key: Key}"

  echo "Removing backups older than $BACKUP_KEEP_DAYS days from $S3_BUCKET..."
  aws $aws_args s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${BACKUPS_QUERY}" \
    --output text \
    | xargs -r -n1 -t -I 'KEY' aws $aws_args s3 rm "s3://${S3_BUCKET}/KEY"
  echo "Old backup removal complete."
fi