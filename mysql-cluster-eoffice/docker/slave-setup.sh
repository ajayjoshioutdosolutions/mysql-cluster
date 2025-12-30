#!/bin/bash
set -e

# Flag file to prevent re-configuration
if [ -f /var/lib/mysql/replication_configured ]; then
    echo "Replication already configured. Skipping."
    exit 0
fi

echo "Waiting for Master to be ready..."
# Although docker-compose healthcheck handles this, a small wait helps ensure strict ordering if manual restart happens
sleep 5

echo "Configuring Replication..."

mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
    STOP SLAVE;
    CHANGE MASTER TO 
      MASTER_HOST='mysql-master', 
      MASTER_PORT=3306,
      MASTER_USER='${MYSQL_REPLICATION_USER}', 
      MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}', 
      MASTER_AUTO_POSITION=1;
    START SLAVE;
EOSQL

touch /var/lib/mysql/replication_configured
echo "Replication Configured Successfully."
