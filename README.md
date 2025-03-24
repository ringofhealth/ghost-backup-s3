# Ghost Backup S3

A Docker container for automated backups of Ghost blogs to S3-compatible storage. This container backs up both the MySQL database and Ghost content files (themes, images, etc.) to create complete backups that can be easily restored.

## Features

- 🔄 **Complete Backup Solution**: Backs up both MySQL database and Ghost content
- 🕒 **Scheduled Backups**: Run backups on a schedule (using cron syntax)
- 🔐 **Encryption**: Optional GPG encryption of backups
- 🧹 **Backup Rotation**: Automatically remove old backups
- ☁️ **S3 Compatible**: Works with AWS S3, MinIO, and other S3-compatible storage
- 🔄 **Simple Restore**: One-line command to restore your Ghost blog

## Quick Start

### 1. Build the Docker image

```bash
docker build -t ghost-backup-s3 .
```

### 2. Add to your Ghost Docker Compose setup

Add the ghost-backup service to your existing docker-compose.yml:

```yaml
ghost-backup:
  image: ghost-backup-s3:latest
  restart: always
  environment:
    SCHEDULE: "@daily" # Run backup daily
    BACKUP_KEEP_DAYS: 30 # Keep backups for 30 days
    PASSPHRASE: your-secret-key # Optional encryption key

    # S3 Configuration
    S3_REGION: us-east-1
    S3_ACCESS_KEY_ID: your-access-key
    S3_SECRET_ACCESS_KEY: your-secret-key
    S3_BUCKET: your-ghost-backups
    S3_PREFIX: ghost/backups

    # MySQL Configuration
    MYSQL_HOST: db
    MYSQL_PORT: 3306
    MYSQL_DATABASE: ghost_prod
    MYSQL_ROOT_PASSWORD: your-mysql-root-password
  volumes:
    - ghost_content:/ghost_content:ro
  depends_on:
    - db
    - ghost
```

### 3. Start your services

```bash
docker-compose up -d
```

## Environment Variables

### Required Variables

- `MYSQL_HOST`: MySQL host
- `MYSQL_DATABASE`: MySQL database name
- `S3_BUCKET`: S3 bucket name
- Either `MYSQL_ROOT_PASSWORD` or (`MYSQL_USER` + `MYSQL_PASSWORD`)
- `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`: S3 credentials

### Optional Variables

- `MYSQL_PORT`: MySQL port (default: 3306)
- `MYSQLDUMP_EXTRA_OPTS`: Additional options for mysqldump
- `GHOST_CONTENT_DIR`: Ghost content directory (default: /ghost_content)
- `S3_REGION`: S3 region (default: us-west-1)
- `S3_PREFIX`: Path prefix in the bucket (default: backup)
- `S3_ENDPOINT`: For non-AWS S3 providers
- `S3_S3V4`: Use S3v4 signature (yes/no, default: no)
- `SCHEDULE`: Cron schedule (e.g., @daily, @weekly, or '0 3 \* \* \*')
- `PASSPHRASE`: Encryption passphrase
- `BACKUP_KEEP_DAYS`: Days to keep backups before deletion

## Backup and Restore Commands

### Manual Backup

To trigger a manual backup:

```bash
docker-compose exec ghost-backup bash /backup.sh
```

### Restore from Backup

To restore from the latest backup:

```bash
docker-compose exec ghost-backup bash /restore.sh
```

To restore from a specific backup:

```bash
# Restore using timestamp
docker-compose exec ghost-backup bash /restore.sh 2025-03-24T14:30:00

# Or restore using full filename
docker-compose exec ghost-backup bash /restore.sh ghost_prod_2025-03-24T14:30:00.tar.gz
```

## Schedule Syntax

The `SCHEDULE` environment variable supports:

- Standard cron expressions (e.g., `0 3 * * *` for 3 AM daily)
- Shortcuts: `@yearly`, `@monthly`, `@weekly`, `@daily`, `@hourly`

## Example Usage with Existing Ghost Installation

1. Add the ghost-backup service to your existing docker-compose.yml
2. Ensure your Ghost content volume is mounted to the backup container
3. Configure S3 credentials and bucket information
4. Start the service to enable scheduled backups

## Customization

### Using Non-AWS S3 Storage

For MinIO or other S3-compatible storage:

```yaml
environment:
  # ... other settings ...
  S3_ENDPOINT: https://minio.example.com
  S3_S3V4: yes
```

### Advanced MySQL Options

For large databases or specific requirements:

```yaml
environment:
  # ... other settings ...
  MYSQLDUMP_EXTRA_OPTS: "--ignore-table=ghost_prod.sessions --no-tablespaces"
```

### Build for Linux

docker build --platform linux/amd64 -t ghost-backup-s3 .
docker build --platform linux/amd64 -t ringofregen/ghost-s3-backup:0.3 .

## License

MIT
