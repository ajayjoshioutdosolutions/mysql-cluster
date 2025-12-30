-- =====================================================
-- ProxySQL READ-HEAVY Optimized Configuration
-- 3 Slaves for Maximum Read Performance
-- =====================================================

-- =====================================================
-- 1. SLAVE CONNECTION OPTIMIZATION
-- =====================================================

-- Increase max connections per slave (3 slaves x 1000 = 3000 total read capacity)
UPDATE mysql_servers SET max_connections=1000 WHERE hostgroup_id=20;

-- Equal weight for load balancing (round-robin across 3 slaves)
UPDATE mysql_servers SET weight=1000 WHERE hostgroup_id=20;

-- Master connections (writes are ~10% of traffic)
UPDATE mysql_servers SET max_connections=500 WHERE hostgroup_id=10;

-- =====================================================
-- 2. CONNECTION POOLING FOR HIGH READ VOLUME
-- =====================================================

-- Maximum frontend connections (clients connecting to ProxySQL)
UPDATE global_variables SET variable_value='2000' WHERE variable_name='mysql-max_connections';

-- Keep more free connections in pool for instant reads
UPDATE global_variables SET variable_value='30' WHERE variable_name='mysql-free_connections_pct';

-- Faster connection timeout (ms) - fail fast, retry on another slave
UPDATE global_variables SET variable_value='5000' WHERE variable_name='mysql-connect_timeout_server';

-- Long connection keep-alive (8 hours) - reuse connections efficiently
UPDATE global_variables SET variable_value='28800000' WHERE variable_name='mysql-wait_timeout';

-- Server ping timeout (ms)
UPDATE global_variables SET variable_value='500' WHERE variable_name='mysql-ping_timeout_server';

-- =====================================================
-- 3. THREAD POOL FOR HIGH CONCURRENCY READS
-- =====================================================

-- Worker threads (set to 2x-4x CPU cores for read-heavy)
UPDATE global_variables SET variable_value='32' WHERE variable_name='mysql-threads';

-- Stack size per thread (1MB)
UPDATE global_variables SET variable_value='1048576' WHERE variable_name='mysql-stacksize';

-- =====================================================
-- 4. SESSION CONSISTENCY (Required for accuracy)
-- =====================================================

-- CRITICAL: Keep multiplexing OFF for data consistency
UPDATE global_variables SET variable_value='false' WHERE variable_name='mysql-multiplexing';
UPDATE global_variables SET variable_value='true' WHERE variable_name='mysql-autocommit_false_not_reusable';

-- Session idle timeout (1 hour) - keep sessions for faster repeated queries
UPDATE global_variables SET variable_value='3600000' WHERE variable_name='mysql-session_idle_ms';

-- =====================================================
-- 5. FAST HEALTH CHECKS (Quick failover)
-- =====================================================

-- Ping slaves every 1 second
UPDATE global_variables SET variable_value='1000' WHERE variable_name='mysql-monitor_ping_interval';

-- Check slave status every 1 second
UPDATE global_variables SET variable_value='1000' WHERE variable_name='mysql-monitor_read_only_interval';

-- Check replication lag every 500ms
UPDATE global_variables SET variable_value='500' WHERE variable_name='mysql-monitor_replication_lag_interval';

-- Remove slave from pool if lag > 5 seconds
UPDATE global_variables SET variable_value='5' WHERE variable_name='mysql-monitor_slave_lag_when_null';

-- Shun slave after 3 consecutive failures
UPDATE global_variables SET variable_value='3' WHERE variable_name='mysql-shun_on_failures';

-- Recovery time (ms) - how long before retrying a shunned server
UPDATE global_variables SET variable_value='10000' WHERE variable_name='mysql-shun_recovery_time_sec';

-- =====================================================
-- 6. QUERY ROUTING (Same as before)
-- =====================================================

DELETE FROM mysql_query_rules;

-- Writes to Master
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (1, 1, '^(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|TRUNCATE)', 10, 1, 'Writes to master');

INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (2, 1, '^SELECT.*FOR UPDATE', 10, 1, 'SELECT FOR UPDATE to master');

INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (3, 1, '^SELECT.*LOCK IN SHARE MODE', 10, 1, 'SELECT LOCK to master');

INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (4, 1, '^(START TRANSACTION|BEGIN|COMMIT|ROLLBACK)', 10, 1, 'Transactions to master');

INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (5, 1, '^SET', 10, 1, 'SET to master');

-- ALL reads to Slaves (load balanced across 3 slaves)
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (10, 1, '^SELECT', 20, 1, 'Reads distributed to 3 slaves');

-- =====================================================
-- 7. APPLY ALL CONFIGURATIONS
-- =====================================================

LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
LOAD MYSQL VARIABLES TO RUNTIME;

SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
SAVE MYSQL VARIABLES TO DISK;

-- =====================================================
-- VERIFICATION
-- =====================================================

SELECT '=== SERVER CONFIGURATION ===' as '';
SELECT hostgroup_id, hostname, status, weight, max_connections 
FROM mysql_servers ORDER BY hostgroup_id;

SELECT '=== QUERY RULES ===' as '';
SELECT rule_id, match_pattern, destination_hostgroup, comment 
FROM mysql_query_rules ORDER BY rule_id;

SELECT '=== KEY SETTINGS ===' as '';
SELECT variable_name, variable_value 
FROM global_variables 
WHERE variable_name IN (
    'mysql-multiplexing', 
    'mysql-max_connections',
    'mysql-threads',
    'mysql-free_connections_pct',
    'mysql-monitor_ping_interval'
);
