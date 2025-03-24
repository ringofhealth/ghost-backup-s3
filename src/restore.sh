#!/bin/bash

set -u # Intentionally not using -e to handle errors gracefully
set -o pipefail

# Load environment variables
source /env.sh

# Set S3 URI base
S3_URI_BASE="s3://${S3_BUCKET}/${S3_PREFIX}"

# Determine file extension based on encryption setting
if [ -z "${PASSPHRASE:-}" ]; then
  FILE_EXT=".tar.gz"
else
  FILE_EXT=".tar.gz.gpg"
fi

# Get backup filename, either from argument or find latest
if [ $# -eq 1 ]; then
  # Use the provided timestamp or full filename
  if [[ "$1" == *".tar.gz"* ]]; then
    BACKUP_FILENAME="$1"
  else
    TIMESTAMP="$1"
    BACKUP_FILENAME="${MYSQL_DATABASE}_${TIMESTAMP}${FILE_EXT}"
  fi
else
  echo "Finding latest backup for $MYSQL_DATABASE..."
  BACKUP_FILENAME=$(
    aws $aws_args s3 ls "${S3_URI_BASE}/" | grep "${MYSQL_DATABASE}_" | sort | tail -n 1 | awk '{ print $4 }'
  )
  
  if [ -z "$BACKUP_FILENAME" ]; then
    echo "No backups found for $MYSQL_DATABASE in $S3_URI_BASE"
    exit 1
  fi
fi

echo "Using backup: $BACKUP_FILENAME"

# Create temp directory for restoration
TEMP_DIR=$(mktemp -d)

# Fetch backup from S3
echo "Fetching backup from S3..."
aws $aws_args s3 cp "${S3_URI_BASE}/${BACKUP_FILENAME}" "${TEMP_DIR}/${BACKUP_FILENAME}"

# Decrypt if necessary
if [[ "$BACKUP_FILENAME" == *.gpg ]]; then
  if [ -z "${PASSPHRASE:-}" ]; then
    echo "Error: Encrypted backup but no PASSPHRASE provided"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  echo "Decrypting backup..."
  gpg --quiet --batch --passphrase "$PASSPHRASE" --decrypt "${TEMP_DIR}/${BACKUP_FILENAME}" > "${TEMP_DIR}/${BACKUP_FILENAME%.gpg}"
  rm "${TEMP_DIR}/${BACKUP_FILENAME}"
  BACKUP_FILENAME="${BACKUP_FILENAME%.gpg}"
fi

# Extract archive
echo "Extracting backup files..."
mkdir -p "${TEMP_DIR}/extracted"
tar -xzf "${TEMP_DIR}/${BACKUP_FILENAME}" -C "${TEMP_DIR}/extracted"

# Restore database
echo "Restoring database..."
if [ -f "${TEMP_DIR}/extracted/ghost_database.sql" ]; then
  # First check if database exists
  DB_EXISTS=$(mysql $MYSQL_AUTH_OPTS -e "SHOW DATABASES LIKE '$MYSQL_DATABASE'" | grep "$MYSQL_DATABASE")
  
  if [ -z "$DB_EXISTS" ]; then
    echo "Creating database $MYSQL_DATABASE..."
    mysql $MYSQL_AUTH_OPTS -e "CREATE DATABASE $MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
  else
    echo "Database $MYSQL_DATABASE already exists, proceeding with restore..."
  fi
  
  # Import the database
  mysql $MYSQL_AUTH_OPTS $MYSQL_DATABASE < "${TEMP_DIR}/extracted/ghost_database.sql"
  echo "Database restore completed"
else
  echo "Error: Database backup file not found in archive"
  exit 1
fi

# Restore Ghost content
if [ -f "${TEMP_DIR}/extracted/ghost_content.tar.gz" ]; then
  echo "Restoring Ghost content..."
  
  # Ensure content directory exists
  if [ -d "$GHOST_CONTENT_DIR" ]; then
    # Remove existing content (optional, can be commented out for safety)
    echo "Removing existing content..."
    rm -rf $GHOST_CONTENT_DIR/*
    
    # Extract content
    tar -xzf "${TEMP_DIR}/extracted/ghost_content.tar.gz" -C $GHOST_CONTENT_DIR
    echo "Content restore completed"
  else
    echo "Error: Ghost content directory $GHOST_CONTENT_DIR doesn't exist or is not mounted"
    exit 1
  fi
else
  echo "Warning: Ghost content backup not found in archive or is empty"
fi

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Restore complete!"
echo "Note: You may need to restart your Ghost container for changes to take effect."