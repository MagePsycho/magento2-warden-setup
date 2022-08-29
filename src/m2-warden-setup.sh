#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "./.m2-warden-setup.conf" ]]; then
    echo "Config file does not exist: ./.m2-warden-setup.conf"
    exit 1
fi

source "./.m2-warden-setup.conf"

APP_DOMAIN="${M2_PROJECT_NAME}.test"

echo "Checking prerequisites..."
if [[ ! -f './bin/magento' ]] || [[ ! -f './app/etc/di.xml' ]]; then
    echo "Current directory $(pwd) is not Magento2 root."
    exit 1
fi
if [[ ! -f './app/etc/env.php' ]]; then
    # cp env-warden.php app/etc/env.php
    echo "./app/etc/env.php file is missing."
    exit 1
fi
if [[ ! -f "$M2_SQL_DUMP" ]]; then
    echo "SQL dump: ${M2_SQL_DUMP} not found."
    exit 1
fi

echo "Preparing .env file..."
echo "WARDEN_ENV_NAME=$M2_PROJECT_NAME
WARDEN_ENV_TYPE=magento2
WARDEN_WEB_ROOT=/

TRAEFIK_DOMAIN=$APP_DOMAIN
TRAEFIK_SUBDOMAIN=

WARDEN_DB=1
WARDEN_ELASTICSEARCH=1
WARDEN_VARNISH=0
WARDEN_RABBITMQ=0
WARDEN_REDIS=1

ELASTICSEARCH_VERSION=7.6
MARIADB_VERSION=10.3
NODE_VERSION=10
COMPOSER_VERSION=${COMPOSER_VERSION}
PHP_VERSION=${PHP_VERSION}
PHP_XDEBUG_3=${PHP_XDEBUG_3}
RABBITMQ_VERSION=3.8
REDIS_VERSION=5.0
VARNISH_VERSION=6.0

WARDEN_SYNC_IGNORE=

WARDEN_ALLURE=0
WARDEN_SELENIUM=0
WARDEN_SELENIUM_DEBUG=0
WARDEN_BLACKFIRE=0
WARDEN_SPLIT_SALES=0
WARDEN_SPLIT_CHECKOUT=0
WARDEN_TEST_DB=0
WARDEN_MAGEPACK=0

BLACKFIRE_CLIENT_ID=
BLACKFIRE_CLIENT_TOKEN=
BLACKFIRE_SERVER_ID=
BLACKFIRE_SERVER_TOKEN=" > "./.env"

warden sign-certificate "$APP_DOMAIN"
warden env up

echo "Importing db..."
if [[ $M2_SQL_DUMP == *.sql ]]; then
    pv "$M2_SQL_DUMP" | warden db import
else
    pv "$M2_SQL_DUMP" | gunzip -c | warden db import
fi

warden db import <<-EOL
DELETE FROM core_config_data WHERE path LIKE '%web%base_url%' OR path IN ('web/url/redirect_to_base', 'web/session/use_frontend_sid');
DELETE FROM core_config_data WHERE path LIKE 'web/secure/use%';
DELETE FROM core_config_data where path like '%cookie%';
SET @BASE_URL = 'https://${APP_DOMAIN}/';
SET @COOKIE_DOMAIN = '.${APP_DOMAIN}';

INSERT INTO core_config_data (scope, scope_id, path, value)
VALUES
('default', 0, 'web/url/redirect_to_base', 0),
('default', 0, 'web/session/use_frontend_sid', 0),
('default', 0, 'web/unsecure/base_url', @BASE_URL),
('default', 0, 'web/secure/base_url', @BASE_URL),
('default', 0, 'web/secure/use_in_frontend', 1),
('default', 0, 'web/secure/use_in_adminhtml', 1),
('default', 0, 'web/cookie/cookie_path','/'),
('default', 0, 'web/cookie/cookie_domain',@COOKIE_DOMAIN),
('default', 0, 'web/cookie/cookie_httponly',1),
('default', 0, 'web/cookie/cookie_lifetime',360000);
EOL

echo 'Creating new admin user...'
warden env exec -T php-fpm bin/magento admin:user:create \
    --admin-password="${ADMIN_PASS}" \
    --admin-user="${ADMIN_USER}" \
    --admin-firstname="Local" \
    --admin-lastname="Admin" \
    --admin-email="${ADMIN_USER}@${APP_DOMAIN}"

# Prepare for dev environment
echo 'Deploy static content...'
warden shell -c "bin/magento setup:static-content:deploy -f"

echo 'Configuring admin security settings for development...'
warden shell -c "bin/magento config:set admin/security/session_lifetime 31536000"
warden shell -c "bin/magento config:set admin/security/password_lifetime ''"
warden shell -c "bin/magento config:set admin/security/password_is_forced 0"

# @todo add m2 alias for bin/magento ...

echo "Creating /etc/hosts entry..."
if grep -Eq "127.0.0.1[[:space:]]+${APP_DOMAIN}" /etc/hosts; then
    echo "Entry ${APP_DOMAIN} already exists in host file"
else
    echo "127.0.0.1 ${APP_DOMAIN}" | sudo tee -a /etc/hosts || echo "Unable to write host to /etc/hosts"
fi

xdg-open "https://${APP_DOMAIN}/"
