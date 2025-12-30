#!/bin/bash

# Configuration
DATABASES=("eoffice_2023" "eoffice_2024" "eoffice_2025")
TARGET_CONTAINER="mysql-master"
TARGET_USER="root"
# We try to load target password from .env, otherwise prompt
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi
TARGET_PASS="${MYSQL_ROOT_PASSWORD}"

echo "=========================================="
echo "   Database Migration Tool (Host -> Docker)"
echo "=========================================="
echo "Target Container: $TARGET_CONTAINER"
echo "Databases to Migrate: ${DATABASES[*]}"
echo "=========================================="

# Check for mysqldump
if ! command -v mysqldump &> /dev/null; then
    echo "Error: 'mysqldump' could not be found on your host system."
    echo "Please install mysql-client (e.g., sudo apt install mysql-client)"
    exit 1
fi

# Prompt for Source Credentials
echo "Please enter details for the SOURCE database (Local Host):"
read -p "Source MySQL User (default: root): " SOURCE_USER
SOURCE_USER=${SOURCE_USER:-root}
read -s -p "Source MySQL Password: " SOURCE_PASS
echo ""
read -p "Source MySQL Host (default: 127.0.0.1): " SOURCE_HOST
SOURCE_HOST=${SOURCE_HOST:-127.0.0.1}

# Confirm Target Credentials
if [ -z "$TARGET_PASS" ]; then
    echo ""
    read -s -p "Target Docker ($TARGET_CONTAINER) Root Password: " TARGET_PASS
    echo ""
fi

echo ""
echo "Starting Migration..."

for DB in "${DATABASES[@]}"; do
    echo "------------------------------------------"
    echo "Processing: $DB"
    
    # Check if DB exists on source
    echo -n "Checking source... "
    mysql -h "$SOURCE_HOST" -u "$SOURCE_USER" -p"$SOURCE_PASS" -e "USE $DB" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "SKIPPED (Database '$DB' not found on source)"
        continue
    fi
    echo "FOUND."

    # Create DB on Target
    echo -n "Creating DB on target... "
    docker exec -i "$TARGET_CONTAINER" mysql -u "$TARGET_USER" -p"$TARGET_PASS" -e "CREATE DATABASE IF NOT EXISTS $DB;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "OK."
    else
        echo "FAILED."
        exit 1
    fi

    # Migrate Data
    echo "Migrating data (This may take a while for 400MB)..."
    mysqldump -h "$SOURCE_HOST" -u "$SOURCE_USER" -p"$SOURCE_PASS" --single-transaction --quick --lock-tables=false "$DB" | \
    docker exec -i "$TARGET_CONTAINER" mysql -u "$TARGET_USER" -p"$TARGET_PASS" "$DB"

    if [ $? -eq 0 ]; then
        echo "SUCCESS: $DB migrated."
    else
        echo "ERROR: Migration failed for $DB."
    fi
done

echo "=========================================="
echo "Migration Complete."
