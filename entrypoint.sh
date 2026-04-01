#!/bin/bash

set -e

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"root"}
DATADIR="/var/lib/mysql"

# Only run setup on first start (data dir not yet initialized)
if [ ! -d "$DATADIR/mysql" ]; then
	echo "[i] Initializing data directory..."
	mysqld --initialize-insecure --user=mysql --datadir="$DATADIR"

	echo "[i] Starting temporary server for initial setup..."
	mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
	pid="$!"

	for i in $(seq 1 30); do
		if mysqladmin ping --silent 2>/dev/null; then
			break
		fi
		sleep 1
	done

	echo "[i] Setting root password."
	mysql --user=root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"

	echo "[i] Granting root remote access."
	mysql --user=root --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

	if [ -n "$MYSQL_DATABASE" ]; then
		echo "[i] Creating database: $MYSQL_DATABASE"
		mysql --user=root --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
	fi

	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		echo "[i] Creating user: $MYSQL_USER"
		if [ -n "$MYSQL_DATABASE" ]; then
			mysql --user=root --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
		else
			mysql --user=root --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
		fi
	fi

	if [ -d "/docker-entrypoint-initdb.d" ] && [ "$(ls -A /docker-entrypoint-initdb.d 2>/dev/null)" ]; then
		echo "[i] Running init files from /docker-entrypoint-initdb.d:"
		for f in /docker-entrypoint-initdb.d/*.sql; do
			echo "[i] Running $f"
			mysql --user=root --password="$MYSQL_ROOT_PASSWORD" < "$f"
		done
	fi

	echo "[i] Stopping temporary server..."
	mysqladmin --user=root --password="$MYSQL_ROOT_PASSWORD" shutdown
	wait "$pid"

	echo "[i] Initial setup complete."
fi

exec mysqld --user=mysql "$@"
