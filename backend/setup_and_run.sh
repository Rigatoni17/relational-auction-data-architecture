#!/usr/bin/env bash
set -euo pipefail

# setup_and_run.sh
# Usage:
#   ROOT_PASS='your_root_password' ./setup_and_run.sh
# This script will:
# - start MySQL (Homebrew) if available
# - create the auctiondb schema and buyme_app user (matching app.properties)
# - import the provided SQL seed
# - build the WAR and run it with Jetty on port 8080

ROOT_PASS=${ROOT_PASS:-}
if [ -z "${ROOT_PASS}" ]; then
  echo "ERROR: Please set ROOT_PASS environment variable, e.g."
  echo "  ROOT_PASS='your_root_password' $0"
  exit 1
fi

# Allow overriding host/port if socket access is not available (e.g., on macOS)
MYSQL_HOST=${MYSQL_HOST:-127.0.0.1}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_OPTS=(-h "${MYSQL_HOST}" -P "${MYSQL_PORT}")

echo "Starting MySQL (if Homebrew-managed)..."
if command -v brew >/dev/null 2>&1; then
  brew services start mysql || true
else
  echo "brew not found — ensure MySQL server is running before continuing."
fi

echo "Creating database and application user..."
mysql "${MYSQL_OPTS[@]}" -uroot -p"${ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS auctiondb;"

# Check whether mysql_native_password plugin is available on the server
PLUGIN_EXISTS=$(mysql "${MYSQL_OPTS[@]}" -uroot -p"${ROOT_PASS}" -N -B -e "SELECT PLUGIN_NAME FROM information_schema.PLUGINS WHERE PLUGIN_NAME='mysql_native_password';" 2>/dev/null || true)
if [ -n "${PLUGIN_EXISTS}" ]; then
  echo "mysql_native_password plugin available — creating user with that plugin"
  mysql "${MYSQL_OPTS[@]}" -uroot -p"${ROOT_PASS}" -e "CREATE USER IF NOT EXISTS 'buyme_app'@'localhost' IDENTIFIED WITH mysql_native_password BY 'StrongP@ssw0rd!'; GRANT ALL PRIVILEGES ON auctiondb.* TO 'buyme_app'@'localhost'; FLUSH PRIVILEGES;"
else
  echo "mysql_native_password plugin not available — creating user with default authentication"
  mysql "${MYSQL_OPTS[@]}" -uroot -p"${ROOT_PASS}" -e "CREATE USER IF NOT EXISTS 'buyme_app'@'localhost' IDENTIFIED BY 'StrongP@ssw0rd!'; GRANT ALL PRIVILEGES ON auctiondb.* TO 'buyme_app'@'localhost'; FLUSH PRIVILEGES;"
fi

echo "Importing schema and seeded data..."
mysql "${MYSQL_OPTS[@]}" -uroot -p"${ROOT_PASS}" auctiondb < sql/auctiondb.sql

echo "Building the project (skip tests)..."
mvn -DskipTests package

echo "Starting Jetty with generated WAR on port 8080 (will run in foreground)."
echo "If you want to run in background, run the jetty command yourself or use nohup/screen."
mvn org.eclipse.jetty:jetty-maven-plugin:11.0.15:run-war -Djetty.port=8080
