# MySQL HA Cluster with ProxySQL

This project provides a production-ready MySQL High Availability cluster using Docker. It features:
- **1 Master**: Handles all WRITE operations (INSERT, UPDATE, DELETE, Transactions).
- **3 Slaves**: Handle READ operations (SELECT), load-balanced via round-robin.
- **ProxySQL**: Transparently routes traffic to the correct server based on the query type.

## Quick Start
```bash
# Start the stack
docker-compose up -d --build

# Stop the stack
docker-compose down
```

## Connecting Laravel
Update your Laravel `.env` file to connect to the **ProxySQL** container. Do **not** connect directly to the Master or Slaves.

```dotenv
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=6033        # Important: Connect to ProxySQL port, NOT 3306
DB_DATABASE=your_db # Create this DB first if needed
DB_USERNAME=app_user
DB_PASSWORD=app_secret_password
```

**Note**: You can change these credentials in the root `.env` file of this project.

## Architecture & Ports

| Port | Usage | Who uses this? |
| :--- | :--- | :--- |
| **6033** | **Application Traffic** | **Use this in Laravel**. It handles automatic Read/Write splitting. |
| **8081** | **Visual DB Admin** | **Use this in Browser** (PHPMyAdmin). View tables, run SQL manually. |
| **6032** | **Proxy Configuration** | Only for DevOps/SysAdmins to configure load balancing rules. |

## Administration

### Check Replication Status
To verify that all slaves are syncing correctly:
```bash
# Run on any slave (e.g., mysql-slave1)
docker exec mysql-slave1 mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW REPLICA STATUS\G"
```

### Check Load Balancing
Run the included benchmark script to see traffic distribution:
```bash
./benchmark.sh
```

### User Management
New database users should be created on the **Master**. The replication process will propagate them to all slaves automatically.
```bash
docker exec -it mysql-master mysql -u root -p
```

### Importing SQL Data
To import an SQL dump (e.g., `structure.sql`) into the Master database:

**Method 1: Direct Import** (Quickest for smaller files)
Run this command from your host machine:
```bash
# syntax: docker exec -i [container] mysql ... < [local_file]
docker exec -i mysql-master mysql -u root -p${MYSQL_ROOT_PASSWORD} your_db_name < /path/to/your_file.sql
```

**Method 2: Copy & Import** (Reliable for large files)
1. Copy the file into the container:
```bash
docker cp /path/to/large_dump.sql mysql-master:/tmp/dump.sql
```
2. Import via MySQL Shell:
```bash
docker exec -i mysql-master mysql -u root -p${MYSQL_ROOT_PASSWORD} your_db_name < /tmp/dump.sql
```
