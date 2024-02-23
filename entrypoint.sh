#!/bin/bash

set -e

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"root"}
MYSQL_USER=${MYSQL_USER:-""}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}
MYSQL_DATABASE=${MYSQL_DATABASE:-""}

echo "[i] Setting up new power user credentials."
service mysql start $ sleep 10

echo "[i] Setting root new password."
mysql --user=root --password=root -e "UPDATE mysql.user set authentication_string=password('$MYSQL_ROOT_PASSWORD') where user='root'; FLUSH PRIVILEGES;"

echo "[i] Setting root remote password."
mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

if [ -n "$MYSQL_DATABASE" ]; then
	echo "[i] Creating datebase: $MYSQL_DATABASE"
	mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci; FLUSH PRIVILEGES;"

	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		echo "[i] Create new User: $MYSQL_USER with password $MYSQL_PASSWORD for new database $MYSQL_DATABASE."
		mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
	else
		echo "[i] Don\`t need to create new User."
	fi
else
	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		echo "[i] Create new User: $MYSQL_USER with password $MYSQL_PASSWORD for all database."
		mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
	else
		echo "[i] No need to create a new User."
	fi
fi

service mysql stop $ sleep 10

exec "mysqld_safe"
