FROM alpine:3.18

# Install required packages
RUN apk update && \
    apk add --no-cache \
    mysql-client \
    gnupg \
    aws-cli \
    curl \
    tar \
    gzip \
    bash && \
    # Install go-cron for scheduling
    curl -L https://github.com/ivoronin/go-cron/releases/download/v0.0.5/go-cron_0.0.5_linux_amd64.tar.gz -O && \
    tar xvf go-cron_0.0.5_linux_amd64.tar.gz && \
    rm go-cron_0.0.5_linux_amd64.tar.gz && \
    mv go-cron /usr/local/bin/go-cron && \
    chmod u+x /usr/local/bin/go-cron && \
    # Cleanup
    rm -rf /var/cache/apk/*

# Set default environment variables
ENV MYSQL_DATABASE ''
ENV MYSQL_HOST ''
ENV MYSQL_PORT 3306
ENV MYSQL_USER ''
ENV MYSQL_PASSWORD ''
ENV MYSQL_ROOT_PASSWORD ''
ENV MYSQLDUMP_EXTRA_OPTS ''
ENV GHOST_CONTENT_DIR '/ghost_content'
ENV S3_ACCESS_KEY_ID ''
ENV S3_SECRET_ACCESS_KEY ''
ENV S3_BUCKET ''
ENV S3_REGION 'us-west-1'
ENV S3_PREFIX 'backup'
ENV S3_ENDPOINT ''
ENV S3_S3V4 'no'
ENV SCHEDULE ''
ENV PASSPHRASE ''
ENV BACKUP_KEEP_DAYS ''

# Add scripts
COPY src/env.sh /env.sh
COPY src/run.sh /run.sh
COPY src/backup.sh /backup.sh
COPY src/restore.sh /restore.sh

# Create mount point for Ghost content
VOLUME ["/ghost_content"]

# Make scripts executable
RUN chmod +x /run.sh /backup.sh /restore.sh

# Set working directory
WORKDIR /

# Run the main script
CMD ["bash", "/run.sh"]