#!/bin/bash

# As part of the "Two Phase" build, the first phase typically runs with composer keys mounted,
# allowing the dependencies to be installed, the result of which is committed
if [[ -f /root/.composer/config.json ]]
then
  echo "Running `composer install`"
  composer install
  # Container exists after installation

else
  # Adds docker environment variables where entering them as PHP-FPM environment variables
  VARS=`env | grep ^CFG_`;
  DEST_CONF=/etc/php5/fpm/pool.d/www.conf

  echo 'Importing environment variables (prefixed by CFG_)'
  for p in $VARS
  do
    ENV='env['${p/=/] = }
    echo $ENV >> $DEST_CONF
  done

  if [[ $CFG_APP_DEBUG = 1 || $CFG_APP_DEBUG = '1' || $CFG_APP_DEBUG = 'true' ]]
  then
    echo 'Opcache set to WATCH for file changes'
  else
    echo 'Opcache set to PERFORMANCE, NOT watching for file changes'
    echo 'opcache.revalidate_freq=0' >> /etc/php5/mods-available/opcache.ini
    echo 'opcache.validate_timestamps=0' >> /etc/php5/mods-available/opcache.ini
  fi

  # Configure nginx to use as many workers as there are cores for the running container
  sed -i "s/worker_processes [0-9]\+/worker_processes $(nproc)/" /etc/nginx/nginx.conf
  sed -i "s/worker_connections [0-9]\+/worker_connections 1024/" /etc/nginx/nginx.conf

  echo 'Starting PHP-FPM (background)'
  service php5-fpm start

  echo "Starting Nginx (foreground)"
  exec /usr/sbin/nginx -g "daemon off;"

fi
