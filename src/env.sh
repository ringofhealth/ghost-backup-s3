#!/bin/bash

# Check required environment variables
if [ -z "$S3_BUCKET" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ -z "$MYSQL_DATABASE" ]; then
  echo "You need to set the MYSQL_DATABASE environment variable."
  exit 1
fi

if [ -z "$MYSQL_HOST" ]; then
  echo "You need to set the MYSQL_HOST environment variable."
  exit 1
fi

if [ -z "$MYSQL_USER" ] && [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "You need to set either MYSQL_USER or MYSQL_ROOT_PASSWORD environment variable."
  exit 1
fi

if [ -n "$MYSQL_USER" ] && [ -z "$MYSQL_PASSWORD" ]; then
  echo "You need to set the MYSQL_PASSWORD environment variable when MYSQL_USER is specified."
  exit 1
fi

# Set AWS CLI arguments
if [ -z "$S3_ENDPOINT" ]; then
  aws_args=""
else
  aws_args="--endpoint-url $S3_ENDPOINT"
fi

# Configure AWS credentials
if [ -n "$S3_ACCESS_KEY_ID" ]; then
  export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
fi

if [ -n "$S3_SECRET_ACCESS_KEY" ]; then
  export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
fi

export AWS_DEFAULT_REGION=$S3_REGION

# Determine which MySQL password to use
if [ -n "$MYSQL_PASSWORD" ]; then
  export MYSQL_AUTH_PASSWORD=$MYSQL_PASSWORD
else
  export MYSQL_AUTH_PASSWORD=$MYSQL_ROOT_PASSWORD
  export MYSQL_USER=root
fi

# Set MySQL prefix for authentication
MYSQL_AUTH_OPTS="-h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_AUTH_PASSWORD"

# Ensure S3 prefix doesn't have trailing slash
S3_PREFIX=$(echo "$S3_PREFIX" | sed 's/\/$//')