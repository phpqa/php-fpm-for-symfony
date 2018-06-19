#!/bin/sh
set -e

echo "date.timezone=\"\${TZ}\"" > /usr/local/etc/php/conf.d/timezone.ini

if [ "$1" = "/composer/vendor/bin/requirements-checker" ]; then
  set -- php "$@"
elif [ "$1" = "requirements-checker" ]; then
  set -- php /composer/vendor/bin/"$@"
fi

. $(cd $(dirname $0); pwd)/docker-php-entrypoint
