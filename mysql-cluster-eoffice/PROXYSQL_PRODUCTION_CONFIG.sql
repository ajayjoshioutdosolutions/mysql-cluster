-- =====================================================
-- ProxySQL Production Configuration for Laravel/MySQL
-- Read Distribution with Data Consistency
-- =====================================================

-- 1. Clear existing query rules
DELETE FROM mysql_query_rules;

-- 2. Query Routing Rules (Applied in order by rule_id)

-- Rule 1: Route all WRITE operations to Master (Hostgroup 10)
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (1, 1, '^(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|TRUNCATE)', 10, 1, 'Writes to master');

-- Rule 2: Route SELECT ... FOR UPDATE to Master
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (2, 1, '^SELECT.*FOR UPDATE', 10, 1, 'SELECT FOR UPDATE to master');

-- Rule 3: Route SELECT ... LOCK IN SHARE MODE to Master
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (3, 1, '^SELECT.*LOCK IN SHARE MODE', 10, 1, 'SELECT LOCK to master');

-- Rule 4: Route Transaction statements to Master
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (4, 1, '^(START TRANSACTION|BEGIN|COMMIT|ROLLBACK)', 10, 1, 'Transactions to master');

-- Rule 5: Route SET statements to Master
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (5, 1, '^SET', 10, 1, 'SET to master');

-- Rule 10: Route all other SELECT to Slaves (Hostgroup 20)
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (10, 1, '^SELECT', 20, 1, 'Reads to slaves');

-- 3. Connection Settings (Critical for consistency)
UPDATE global_variables SET variable_value='false' WHERE variable_name='mysql-multiplexing';
UPDATE global_variables SET variable_value='true' WHERE variable_name='mysql-autocommit_false_not_reusable';

-- 4. Apply Configuration
LOAD MYSQL QUERY RULES TO RUNTIME;
LOAD MYSQL VARIABLES TO RUNTIME;

-- 5. Save to disk (persists across restarts)
SAVE MYSQL QUERY RULES TO DISK;
SAVE MYSQL VARIABLES TO DISK;

-- 6. Statistics will reset automatically after LOAD TO RUNTIME
-- Note: stats_mysql_query_rules_reset may not exist in all ProxySQL versions

-- =====================================================
-- Verification Queries
-- =====================================================

-- Verify query rules
SELECT rule_id, match_pattern, destination_hostgroup, comment 
FROM mysql_query_rules 
ORDER BY rule_id;

-- Verify connection settings
SELECT variable_name, variable_value 
FROM global_variables 
WHERE variable_name IN ('mysql-multiplexing', 'mysql-autocommit_false_not_reusable');

-- Check traffic distribution (run after some traffic)
-- SELECT hostgroup, SUM(Queries) as total_queries FROM stats_mysql_connection_pool GROUP BY hostgroup;
