#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/bastion-startup.log"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local n=1
  until "$@"; do
    if [ "$n" -ge "$attempts" ]; then
      log "Command failed after $attempts attempts: $*"
      return 1
    fi
    log "Command failed (attempt $n/$attempts): $*; retrying in ${delay}s"
    n=$((n + 1))
    sleep "$delay"
  done
}

log "Starting bastion-fargate initialization"

# Start SSM Agent
log "Starting AWS Systems Manager Agent"
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Wait for SSM Agent to be ready
log "Waiting for SSM Agent to be ready..."
for i in $(seq 1 30); do
  if systemctl is-active --quiet amazon-ssm-agent; then
    log "SSM Agent is ready"
    break
  fi
  log "Waiting for SSM Agent... attempt $i/30"
  sleep 2
done

# Create database users if RDS endpoint is provided
if [ -n "${RDS_ENDPOINT:-}" ] && [ -n "${RDS_MASTER_USERNAME:-}" ]; then
  log "Configuring database users"
  sleep 5

  # Get RDS master password from Secrets Manager
  MASTER_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "${RDS_MASTER_PASSWORD_SECRET_ARN}" \
    --region "${AWS_REGION}" \
    --query 'SecretString' \
    --output text | jq -r '.password')

  if [ -z "$MASTER_PASSWORD" ]; then
    log "ERROR: Failed to retrieve master password from Secrets Manager"
    exit 1
  fi

  DB_ENGINE="${DB_ENGINE:-mysql}"
  IS_MYSQL=false
  IS_POSTGRES=false

  case "$DB_ENGINE" in
    mysql|mariadb|aurora-mysql)
      IS_MYSQL=true
      ;;
    postgres|aurora-postgresql)
      IS_POSTGRES=true
      ;;
    *)
      log "ERROR: Unsupported database engine: $DB_ENGINE"
      exit 1
      ;;
  esac

  # Wait for database to be ready
  for i in $(seq 1 30); do
    if [ "$IS_MYSQL" = true ]; then
      if mysql -h "${RDS_ENDPOINT}" -u "${RDS_MASTER_USERNAME}" -p"$MASTER_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
        log "Database is ready"
        break
      fi
    else
      if PGPASSWORD="$MASTER_PASSWORD" psql -h "${RDS_ENDPOINT}" -U "${RDS_MASTER_USERNAME}" -d "${RDS_DATABASE_NAME}" -c "SELECT 1;" 2>/dev/null; then
        log "Database is ready"
        break
      fi
    fi
    log "Waiting for database... attempt $i/30"
    sleep 10
  done

  # Create database users based on engine type
  if [ "$IS_MYSQL" = true ]; then
    log "Creating MySQL/MariaDB users"
    mysql -h "${RDS_ENDPOINT}" -u "${RDS_MASTER_USERNAME}" -p"$MASTER_PASSWORD" <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${APP_DB_USERNAME}'@'%' IDENTIFIED BY '${APP_DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
      CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW,
      SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, TRIGGER, REFERENCES
ON \`${RDS_DATABASE_NAME}\`.*TO '${APP_DB_USERNAME}'@'%';
CREATE USER IF NOT EXISTS 'read_only'@'%' IDENTIFIED BY '${DB_READ_ONLY_PASSWORD}';
GRANT SELECT, SHOW VIEW ON \`${RDS_DATABASE_NAME}\`.* TO 'read_only'@'%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user WHERE User IN ('${APP_DB_USERNAME}', 'read_only');
MYSQL_SCRIPT
    DB_EXIT_CODE=$?
  else
    log "Creating PostgreSQL users"
    PGPASSWORD="$MASTER_PASSWORD" psql -h "${RDS_ENDPOINT}" -U "${RDS_MASTER_USERNAME}" -d "${RDS_DATABASE_NAME}" <<POSTGRES_SCRIPT
-- Create application user if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${APP_DB_USERNAME}') THEN
    CREATE USER ${APP_DB_USERNAME} WITH PASSWORD '${APP_DB_PASSWORD}';
  END IF;
END
\$\$;

-- Grant privileges to application user
GRANT CONNECT ON DATABASE ${RDS_DATABASE_NAME} TO ${APP_DB_USERNAME};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${APP_DB_USERNAME};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${APP_DB_USERNAME};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO ${APP_DB_USERNAME};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO ${APP_DB_USERNAME};

-- Create read-only user if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'read_only') THEN
    CREATE USER read_only WITH PASSWORD '${DB_READ_ONLY_PASSWORD}';
  END IF;
END
\$\$;

-- Grant read-only privileges to read_only user
GRANT CONNECT ON DATABASE ${RDS_DATABASE_NAME} TO read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO read_only;

-- List created users
SELECT usename FROM pg_catalog.pg_user WHERE usename IN ('${APP_DB_USERNAME}', 'read_only');
POSTGRES_SCRIPT
    DB_EXIT_CODE=$?
  fi

  unset MASTER_PASSWORD

  if [ "$DB_EXIT_CODE" -eq 0 ]; then
    log "Database application and read-only users created successfully"
  else
    log "ERROR: Failed to create database users"
  fi
fi

log "Bastion-fargate initialization completed"

# Keep container running
exec tail -f /dev/null
