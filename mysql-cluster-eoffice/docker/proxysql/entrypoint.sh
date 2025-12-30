#!/bin/bash

echo "Generating ProxySQL configuration..."
sed -e "s|\${PROXYSQL_MONITOR_USER}|${PROXYSQL_MONITOR_USER}|g" \
    -e "s|\${PROXYSQL_MONITOR_PASSWORD}|${PROXYSQL_MONITOR_PASSWORD}|g" \
    -e "s|\${APP_USER}|${APP_USER}|g" \
    -e "s|\${APP_PASSWORD}|${APP_PASSWORD}|g" \
    -e "s|\${MYSQL_ROOT_PASSWORD}|${MYSQL_ROOT_PASSWORD}|g" \
    /etc/proxysql.cnf.template > /etc/proxysql.cnf

echo "Starting ProxySQL with --initial to force config reload..."
exec proxysql -f --initial -c /etc/proxysql.cnf
