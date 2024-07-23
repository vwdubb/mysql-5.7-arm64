#!/bin/bash

set -e

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"root"}

echo "[i] Setting up new power user credentials."
service mysql start

echo "[i] Setting root new password."
mysql --user=root --password=root -e "UPDATE mysql.user SET authentication_string=password('$MYSQL_ROOT_PASSWORD') WHERE user='root'; FLUSH PRIVILEGES;" 2>/dev/null || true

echo "[i] Setting root remote password."
mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

if [ -n "$MYSQL_DATABASE" ]; then
	echo "[i] Creating datebase: $MYSQL_DATABASE"
	mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci; FLUSH PRIVILEGES;"

	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		echo "[i] Create new User: $MYSQL_USER with password $MYSQL_PASSWORD for new database $MYSQL_DATABASE."
		mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
	else
		echo "[i] No need to create new User."
	fi
else
	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		echo "[i] Create new User $MYSQL_USER with password $MYSQL_PASSWORD"
		mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
	else
		echo "[i] No need to create a new User."
	fi
fi

if [ -d "/docker-entrypoint-initdb.d" ] && [ "$(ls -A /docker-entrypoint-initdb.d)" ]; then
    echo "[i] Processing initialization files in /docker-entrypoint-initdb.d:"

    for sql_file in /docker-entrypoint-initdb.d/*.sql; do
        echo "[i] Processing file $sql_file"
        mysql --user=root --password=$MYSQL_ROOT_PASSWORD < $sql_file
        echo "[i] Done processing $sql_file"
    done

    echo "[i] Finished processing initialization files."
fi

service mysql stop

exec mysqld "$@"
