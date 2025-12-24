#!/bin/bash

# Configuration
BACKUP_DIR="/backups"
RETENTION_DAYS=14
MYSQL_HOST="mysql-master"
MYSQL_USER="root"
# MYSQL_PASSWORD provided by env

echo "Starting Backup Service..."
echo "Retention Policy: Keep backups for $RETENTION_DAYS days."

while true; do
    # Calculate time until next midnight
    CURRENT_EPOCH=$(date +%s)
    TARGET_EPOCH=$(date -d "tomorrow 00:00:00" +%s)
    SLEEP_SECONDS=$((TARGET_EPOCH - CURRENT_EPOCH))

    echo "Sleeping for $SLEEP_SECONDS seconds until midnight..."
    sleep $SLEEP_SECONDS

    DATE=$(date +%Y-%m-%d_%H-%M-%S)
    BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql.gz"

    echo "[$DATE] Starting backup..."
    
    # Perform Backup
    mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASSWORD" --all-databases --single-transaction --quick --lock-tables=false | gzip > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo "[$DATE] Backup successful: $BACKUP_FILE"
        ls -lh "$BACKUP_FILE"
    else
        echo "[$DATE] Backup FAILED!"
    fi

    # Cleanup Old Backups
    echo "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +$RETENTION_DAYS -exec rm {} \;
    
    # Sleep a bit to avoid double-execution if calculation is slightly off
    sleep 60
done
