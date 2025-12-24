CREATE USER 'replicator'@'%' IDENTIFIED BY 'REPL_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;

-- Monitor user
CREATE USER 'proxysql_monitor'@'%'
IDENTIFIED WITH mysql_native_password
BY 'proxysql_monitor_pwd';

GRANT USAGE, REPLICATION CLIENT ON *.*
TO 'proxysql_monitor'@'%';

-- App user
CREATE USER 'app_user'@'%'
IDENTIFIED WITH mysql_native_password
BY 'APP_PASSWORD';

GRANT ALL PRIVILEGES ON your_db.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
