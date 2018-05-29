#!/bin/sh
set -e

echo "date.timezone=\"\${TZ}\"" > /usr/local/etc/php/conf.d/timezone.ini

if [ "$1" = "/vendor/bin/requirements-checker" ]; then
  set -- php "$@"
elif [ "$1" = "requirements-checker" ]; then
  set -- php /vendor/bin/"$@"
fi

. $(cd $(dirname $0); pwd)/docker-php-entrypoint
