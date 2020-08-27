#!/usr/bin/env sh

for entry in `ls /etc/nginx/conf.d/*.template 2> /dev/null`; do
  envsubst '${API_SERVER},${PHP_INDEX_DIR},${PHP_INDEX_FILE}' < $entry > ${entry::-9}
done

rm -f /etc/nginx/conf.d/*.template

/usr/local/openresty/bin/openresty -g 'daemon off;'
