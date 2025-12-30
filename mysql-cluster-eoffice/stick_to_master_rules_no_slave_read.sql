-- ============================================================================
-- ProxySQL Production Configuration Export
-- Generated: 2025-12-28 18:48 IST
-- Purpose: Fix vendor/customer data flickering issue
-- ============================================================================
-- 
-- INSTRUCTIONS FOR PRODUCTION DEPLOYMENT:
-- 1. Connect to ProxySQL admin interface:
--    mysql -h 127.0.0.1 -P 6032 -u admin -padmin
-- 
-- 2. Run this entire script
-- 
-- 3. Verify configuration is applied
-- 
-- ============================================================================

-- ============================================================================
-- STEP 1: BACKUP CURRENT CONFIGURATION (OPTIONAL BUT RECOMMENDED)
-- ============================================================================
-- Run these commands BEFORE applying changes to save current config:
-- 
-- SAVE MYSQL SERVERS TO DISK;
-- SAVE MYSQL USERS TO DISK;
-- SAVE MYSQL VARIABLES TO DISK;
-- SAVE MYSQL QUERY RULES TO DISK;

-- ============================================================================
-- STEP 2: CONFIGURE BACKEND MYSQL SERVERS
-- ============================================================================

-- Clear existing server configuration
DELETE FROM mysql_servers;

-- Add Master Server (Hostgroup 10 - Read/Write)
INSERT INTO mysql_servers (
    hostgroup_id,
    hostname,
    port,
    status,
    weight,
    compression,
    max_connections,
    max_replication_lag,
    use_ssl,
    max_latency_ms,
    comment
) VALUES (
    10,
    'mysql-master',
    3306,
    'ONLINE',
    1,
    0,
    800,
    0,
    0,
    0,
    'Master - Read/Write'
);

-- Add Slave Servers (Hostgroup 20 - Read Only)
-- Note: Currently not used due to consistency requirements
INSERT INTO mysql_servers (
    hostgroup_id,
    hostname,
    port,
    status,
    weight,
    compression,
    max_connections,
    max_replication_lag,
    use_ssl,
    max_latency_ms,
    comment
) VALUES 
(20, 'mysql-slave1', 3306, 'ONLINE', 1, 0, 800, 0, 0, 0, 'Slave 1 - Read Only'),
(20, 'mysql-slave2', 3306, 'ONLINE', 1, 0, 800, 0, 0, 0, 'Slave 2 - Read Only'),
(20, 'mysql-slave3', 3306, 'ONLINE', 1, 0, 800, 0, 0, 0, 'Slave 3 - Read Only');

-- ============================================================================
-- STEP 3: CONFIGURE MYSQL USERS
-- ============================================================================

-- Clear existing users
DELETE FROM mysql_users;

-- Add application user
INSERT INTO mysql_users (
    username,
    password,
    active,
    use_ssl,
    default_hostgroup,
    default_schema,
    schema_locked,
    transaction_persistent,
    fast_forward,
    backend,
    frontend,
    max_connections,
    comment
) VALUES (
    'app_user',
    'app_secret_password',
    1,
    0,
    10,
    NULL,
    0,
    1,
    0,
    1,
    1,
    10000,
    'Application user - routes to master by default'
);

-- Add root user (optional, for admin access)
INSERT INTO mysql_users (
    username,
    password,
    active,
    use_ssl,
    default_hostgroup,
    default_schema,
    schema_locked,
    transaction_persistent,
    fast_forward,
    backend,
    frontend,
    max_connections,
    comment
) VALUES (
    'root',
    'your_password_here',
    1,
    0,
    10,
    NULL,
    0,
    1,
    0,
    1,
    1,
    10000,
    'Root user - admin access'
);

-- ============================================================================
-- STEP 4: CONFIGURE SESSION PERSISTENCE VARIABLES
-- ============================================================================

-- Disable connection multiplexing for session consistency
UPDATE global_variables 
SET variable_value='false' 
WHERE variable_name='mysql-multiplexing';

-- Prevent connection reuse with different autocommit states
UPDATE global_variables 
SET variable_value='true' 
WHERE variable_name='mysql-autocommit_false_not_reusable';

-- Don't treat autocommit=0 as transaction start
UPDATE global_variables 
SET variable_value='false' 
WHERE variable_name='mysql-autocommit_false_is_transaction';

-- Set minimal session idle time
UPDATE global_variables 
SET variable_value='1' 
WHERE variable_name='mysql-session_idle_ms';

-- Disable delay before multiplexing (not used but set for consistency)
UPDATE global_variables 
SET variable_value='0' 
WHERE variable_name='mysql-connection_delay_multiplex_ms';

-- Set transaction timeouts (4 hours)
UPDATE global_variables 
SET variable_value='14400000' 
WHERE variable_name='mysql-max_transaction_idle_time';

UPDATE global_variables 
SET variable_value='14400000' 
WHERE variable_name='mysql-max_transaction_time';

-- ============================================================================
-- STEP 5: CONFIGURE QUERY ROUTING RULES
-- ============================================================================

-- Clear existing query rules
DELETE FROM mysql_query_rules;

-- CURRENT CONFIGURATION: Route ALL queries to master
-- This ensures 100% data consistency and eliminates flickering
INSERT INTO mysql_query_rules (
    rule_id,
    active,
    match_pattern,
    destination_hostgroup,
    apply,
    comment
) VALUES (
    1,
    1,
    '.*',
    10,
    1,
    'Route ALL queries to master for complete consistency'
);

-- ============================================================================
-- ALTERNATIVE CONFIGURATION (FUTURE OPTIMIZATION)
-- ============================================================================
-- Uncomment the following rules to re-enable selective slave reads
-- Only do this after verifying 1-2 weeks of stability!
--
-- DELETE FROM mysql_query_rules;
-- 
-- -- Route SELECT ... FOR UPDATE to master (requires locking)
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (1, 1, '^SELECT.*FOR UPDATE', 10, 1, 'Locking reads to master');
-- 
-- -- Route all write operations to master
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (2, 1, '^(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|TRUNCATE|BEGIN|START TRANSACTION|COMMIT|ROLLBACK)', 10, 1, 'All writes to master');
-- 
-- -- Route critical EAV queries to master
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (10, 1, '_TS[0-9]+', 10, 1, 'Task tables to master');
-- 
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (11, 1, 'task_builder', 10, 1, 'Task metadata to master');
-- 
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (12, 1, 'form_element_builder', 10, 1, 'Form config to master');
-- 
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (13, 1, 'task_assign', 10, 1, 'Task assignments to master');
-- 
-- -- Route other SELECT queries to slaves
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (100, 1, '^SELECT', 20, 1, 'Non-critical reads to slaves');
-- 
-- -- Fallback: route everything else to master
-- INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
-- VALUES (999, 1, '.*', 10, 1, 'Fallback to master');

-- ============================================================================
-- STEP 6: APPLY CONFIGURATION TO RUNTIME
-- ============================================================================

LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL VARIABLES TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;

-- ============================================================================
-- STEP 7: SAVE CONFIGURATION TO DISK (PERSIST ACROSS RESTARTS)
-- ============================================================================

SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL USERS TO DISK;
SAVE MYSQL VARIABLES TO DISK;
SAVE MYSQL QUERY RULES TO DISK;

-- ============================================================================
-- STEP 8: VERIFICATION QUERIES
-- ============================================================================

-- Verify backend servers
SELECT '=== Backend MySQL Servers ===' AS info;
SELECT hostgroup_id, hostname, port, status, weight, max_connections, comment
FROM mysql_servers
ORDER BY hostgroup_id, hostname;

-- Verify users
SELECT '' AS separator;
SELECT '=== MySQL Users ===' AS info;
SELECT username, active, default_hostgroup, transaction_persistent, max_connections, comment
FROM mysql_users;

-- Verify session variables
SELECT '' AS separator;
SELECT '=== Session Persistence Variables ===' AS info;
SELECT variable_name, variable_value
FROM global_variables
WHERE variable_name IN (
    'mysql-multiplexing',
    'mysql-autocommit_false_not_reusable',
    'mysql-autocommit_false_is_transaction',
    'mysql-session_idle_ms',
    'mysql-connection_delay_multiplex_ms'
)
ORDER BY variable_name;

-- Verify query routing rules
SELECT '' AS separator;
SELECT '=== Query Routing Rules ===' AS info;
SELECT rule_id, active, match_pattern, destination_hostgroup, apply, comment
FROM mysql_query_rules
ORDER BY rule_id;

-- Check current connection pool status
SELECT '' AS separator;
SELECT '=== Connection Pool Status ===' AS info;
SELECT hostgroup, srv_host, srv_port, status, ConnUsed, ConnFree, ConnOK, Queries
FROM stats_mysql_connection_pool
WHERE ConnOK > 0 OR Queries > 0
ORDER BY hostgroup, srv_host;

-- ============================================================================
-- POST-DEPLOYMENT TESTING
-- ============================================================================
-- 
-- After applying this configuration:
-- 
-- 1. Test database connectivity:
--    mysql -h 127.0.0.1 -P 6033 -uapp_user -papp_secret_password -e "SELECT @@hostname, @@server_id;"
-- 
-- 2. Verify all queries go to master:
--    SELECT hostgroup, srv_host, Queries FROM stats_mysql_connection_pool WHERE Queries > 0;
--    (Should only show hostgroup 10 with queries)
-- 
-- 3. Test application:
--    - Refresh vendor/customer page 10-20 times
--    - Verify data remains stable
--    - Check for any errors in application logs
-- 
-- 4. Monitor query routing:
--    SELECT rule_id, hits FROM stats_mysql_query_rules ORDER BY hits DESC;
--    (Should show rule_id 1 with all hits)
-- 
-- ============================================================================
-- ROLLBACK PROCEDURE (IF NEEDED)
-- ============================================================================
-- 
-- If you need to rollback to previous configuration:
-- 
-- 1. Restore from backup files (if you saved them):
--    LOAD MYSQL SERVERS FROM DISK;
--    LOAD MYSQL USERS FROM DISK;
--    LOAD MYSQL VARIABLES FROM DISK;
--    LOAD MYSQL QUERY RULES FROM DISK;
--    LOAD MYSQL SERVERS TO RUNTIME;
--    LOAD MYSQL USERS TO RUNTIME;
--    LOAD MYSQL VARIABLES TO RUNTIME;
--    LOAD MYSQL QUERY RULES TO RUNTIME;
-- 
-- 2. Or manually revert specific changes as needed
-- 
-- ============================================================================
-- NOTES
-- ============================================================================
-- 
-- - This configuration routes ALL queries to master for maximum consistency
-- - Slaves are configured but not currently used
-- - Connection multiplexing is disabled for session persistence
-- - Transaction persistence is enabled
-- - This configuration has been tested and verified to fix data flickering
-- 
-- - For production optimization after stability is confirmed (1-2 weeks):
--   Consider uncommenting the alternative configuration to enable slave reads
-- 
-- ============================================================================
-- END OF CONFIGURATION
-- ============================================================================
