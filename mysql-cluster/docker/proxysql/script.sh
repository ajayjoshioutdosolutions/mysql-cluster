#!/bin/bash

echo "Configuring ProxySQL..."

mysql -h 127.0.0.1 -P 6032 -u admin -padmin <<EOF

-- =========================
-- MySQL backend servers
-- =========================
DELETE FROM mysql_servers;

INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight, comment) VALUES
(10, 'mysql-master', 3306, 1, 'Master'),
(20, 'mysql-slave1', 3306, 1, 'Slave 1'),
(20, 'mysql-slave2', 3306, 1, 'Slave 2'),
(20, 'mysql-slave3', 3306, 1, 'Slave 3');

LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

-- =========================
-- Application user (NOT root)
-- =========================
DELETE FROM mysql_users;

INSERT INTO mysql_users
(username, password, default_hostgroup, transaction_persistent, active, max_connections)
VALUES
('app_user', 'APP_PASSWORD', 10, 1, 1, 500);

LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

-- =========================
-- Query routing rules
-- =========================
DELETE FROM mysql_query_rules;

-- Writes → master
INSERT INTO mysql_query_rules
(rule_id, active, match_pattern, destination_hostgroup, apply)
VALUES
(100, 1, '^(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|TRUNCATE)', 10, 1);

-- SELECT FOR UPDATE → master
INSERT INTO mysql_query_rules
(rule_id, active, match_pattern, destination_hostgroup, apply)
VALUES
(200, 1, '^SELECT.*FOR UPDATE', 10, 1);

-- Transactions → master
INSERT INTO mysql_query_rules
(rule_id, active, match_pattern, destination_hostgroup, apply)
VALUES
(300, 1, '^(BEGIN|START TRANSACTION|COMMIT|ROLLBACK)', 10, 1);

-- Plain SELECT → slaves
INSERT INTO mysql_query_rules
(rule_id, active, match_pattern, destination_hostgroup, apply)
VALUES
(400, 1, '^SELECT', 20, 1);

LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;

-- =========================
-- Monitor configuration (FIXED)
-- =========================
UPDATE global_variables SET variable_value='proxysql_monitor'
WHERE variable_name='mysql-monitor_username';

UPDATE global_variables SET variable_value='proxysql_monitor_pwd'
WHERE variable_name='mysql-monitor_password';

LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;

-- =========================
-- Verify
-- =========================
SELECT hostgroup_id, hostname, status FROM mysql_servers;
SELECT username, default_hostgroup FROM mysql_users;
SELECT rule_id, match_pattern, destination_hostgroup FROM mysql_query_rules ORDER BY rule_id;

EOF

echo "ProxySQL configured successfully."
