#!/usr/bin/env bash

#---------------------------------------------------------------------
# configure php-fpm
#---------------------------------------------------------------------

function php-fpm() {

  # Determine the PHP-FPM runtime environment
   CPU=$(grep -c ^processor /proc/cpuinfo); echo "${CPU}"
   TOTALMEM=$(free -m | awk '/^Mem:/{print $2}'); echo "${TOTALMEM}"

   if [[ "$CPU" -le "2" ]]; then TOTALCPU=2; else TOTALCPU="${CPU}"; fi

   # PHP-FPM settings
   if [[ -z $PHP_START_SERVERS ]]; then PHP_START_SERVERS=$(($TOTALCPU / 2)) && echo "${PHP_START_SERVERS}"; fi
   if [[ -z $PHP_MIN_SPARE_SERVERS ]]; then PHP_MIN_SPARE_SERVERS=$(($TOTALCPU / 2)) && echo "${PHP_MIN_SPARE_SERVERS}"; fi
   if [[ -z $PHP_MAX_SPARE_SERVERS ]]; then PHP_MAX_SPARE_SERVERS="${TOTALCPU}" && echo "${PHP_MAX_SPARE_SERVERS}"; fi
   if [[ -z $PHP_MEMORY_LIMIT ]]; then PHP_MEMORY_LIMIT=$(($TOTALMEM / 2)) && echo "${PHP_MEMORY_LIMIT}"; fi
   if [[ -z $PHP_MAX_CHILDREN ]]; then PHP_MAX_CHILDREN=$(($TOTALCPU * 2)) && echo "${PHP_MAX_CHILDREN}"; fi

   # Opcache settings
   if [[ -z $PHP_OPCACHE_ENABLE ]]; then PHP_OPCACHE_ENABLE=1 && echo "${PHP_OPCACHE_ENABLE}"; fi
   if [[ -z $PHP_OPCACHE_MEMORY_CONSUMPTION ]]; then PHP_OPCACHE_MEMORY_CONSUMPTION=$(($TOTALMEM / 6)) && echo "${PHP_OPCACHE_MEMORY_CONSUMPTION}"; fi

   # Set the listening port
   if [[ -z $PHP_FPM_PORT ]]; then echo "PHP-FPM port not set. Default to 9000..." && export PHP_FPM_PORT=9000; else echo "OK, PHP-FPM port is set to $PHP_FPM_PORT"; fi
   # Set the document root. This is usually the same as your NGINX docroot
   if [[ -z $APP_DOCROOT ]]; then export APP_DOCROOT=/app && mkdir -p "${APP_DOCROOT}"; fi

  {
        echo '[global]'
        echo 'include=/etc/php7/php-fpm.d/*.conf'
  } | tee /etc/php7/php-fpm.conf

  {
        echo '[global]'
        echo 'error_log = {{LOG_PREFIX}}/error.log'
        echo
        echo '[www]'
        echo '; if we send this to /proc/self/fd/1, it never appears'
        echo 'access.log = {{LOG_PREFIX}}/access.log'
        echo
        echo 'clear_env = no'
        echo '; ping.path = /ping'
        echo '; Ensure worker stdout and stderr are sent to the main error log.'
        echo 'catch_workers_output = yes'
  } | tee /etc/php7/php-fpm.d/docker.conf

  {
        echo '[global]'
        echo 'daemonize = no'
        echo 'log_level = error'
        echo
        echo '[www]'
        echo 'user = www-data'
        echo 'group = www-data'
        echo 'listen = [::]:{{PHP_FPM_PORT}}'
        echo 'listen.mode = 0666'
        echo 'listen.owner = www-data'
        echo 'listen.group = www-data'
        echo 'pm = static'
        echo 'pm.max_children = {{PHP_MAX_CHILDREN}}'
        echo 'pm.max_requests = 1000'
        echo 'pm.start_servers = {{PHP_START_SERVERS}}'
        echo 'pm.min_spare_servers = {{PHP_MIN_SPARE_SERVERS}}'
        echo 'pm.max_spare_servers = {{PHP_MAX_SPARE_SERVERS}}'
  } | tee /etc/php7/php-fpm.d/zz-docker.conf

  {
        echo 'max_executionn_time=300'
        echo 'memory_limit={{PHP_MEMORY_LIMIT}}M'
        echo 'error_reporting=1'
        echo 'display_errors=0'
        echo 'log_errors=1'
        echo 'user_ini.filename='
        echo 'realpath_cache_size=2M'
        echo 'cgi.check_shebang_line=0'
        echo 'date.timezone=UTC'
        echo 'short_open_tag=Off'
        echo 'session.auto_start=Off'
        echo 'upload_max_filesize=50M'
        echo 'post_max_size=50M'
        echo 'file_uploads=On'

        echo
        echo 'opcache.enable={{PHP_OPCACHE_ENABLE}}'
        echo 'opcache.enable_cli=0'
        echo 'opcache.save_comments=1'
        echo 'opcache.interned_strings_buffer=8'
        echo 'opcache.fast_shutdown=1'
        echo 'opcache.validate_timestamps=2'
        echo 'opcache.revalidate_freq=15'
        echo 'opcache.use_cwd=1'
        echo 'opcache.max_accelerated_files=100000'
        echo 'opcache.max_wasted_percentage=5'
        echo 'opcache.memory_consumption={{PHP_OPCACHE_MEMORY_CONSUMPTION}}M'
        echo 'opcache.consistency_checks=0'
        echo 'opcache.huge_code_pages=1'
        echo
        echo ';opcache.file_cache="{{CACHE_PREFIX}}/fastcgi/.opcache"'
        echo ';opcache.file_cache_only=1'
        echo ';opcache.file_cache_consistency_checks=1'
  } | tee /etc/php7/conf.d/50-setting.ini

  mkdir -p "${CACHE_PREFIX}"/fastcgi/

# Set the configs with the ENV Var
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{CACHE_PREFIX}}|'"${CACHE_PREFIX}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_FPM_PORT}}|'"${PHP_FPM_PORT}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_START_SERVERS}}|'"${PHP_START_SERVERS}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_MIN_SPARE_SERVERS}}|'"${PHP_MIN_SPARE_SERVERS}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_MAX_SPARE_SERVERS}}|'"${PHP_MAX_SPARE_SERVERS}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_MEMORY_LIMIT}}|'"${PHP_MEMORY_LIMIT}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_OPCACHE_ENABLE}}|'"${PHP_OPCACHE_ENABLE}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_OPCACHE_MEMORY_CONSUMPTION}}|'"${PHP_OPCACHE_MEMORY_CONSUMPTION}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{PHP_MAX_CHILDREN}}|'"${PHP_MAX_CHILDREN}"'|g' {} \;
  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{LOG_PREFIX}}|'"${LOG_PREFIX}"'|g' {} \;

}

#---------------------------------------------------------------------
# configure php connection to redis
#---------------------------------------------------------------------

function redis() {

{
      echo 'session.gc_maxlifetime=86400'
      echo 'session.save_handler=redis'
      echo 'session.save_path="tcp://{{REDIS_UPSTREAM}}?weight=1&timeout=2.5&database=3"'
} | tee /etc/php7/conf.d/zz-redis-setting.ini

  find /etc/php7 -maxdepth 3 -type f -exec sed -i -e 's|{{REDIS_UPSTREAM}}|'"${REDIS_UPSTREAM}"'|g' {} \;

}

#---------------------------------------------------------------------
# configure the use of a plugin (install script) for wordpress or similiar
#---------------------------------------------------------------------

function install_plugin() {

if [[ ! -d /usr/src/plugins/$NGINX_APP_PLUGIN ]]; then
  echo "INFO: NGINX_APP_PLUGIN is not located in the plugin directory. Nothing to install..."
else
  echo "OK: Installing NGINX_APP_PLUGIN=$NGINX_APP_PLUGIN..."
  chmod +x /usr/src/plugins/$NGINX_APP_PLUGIN/install
  runplugin="/usr/src/plugins/$NGINX_APP_PLUGIN/install" && /bin/bash -c "${runplugin}"
fi

}

#---------------------------------------------------------------------
# configure monit
#---------------------------------------------------------------------

function monit() {

{
      echo 'set daemon 10'
      echo '    with START DELAY 10'
      echo 'set pidfile /var/run/monit.pid'
      echo 'set statefile /var/run/monit.state'
      echo 'set httpd port 2849 and'
      echo '    use address localhost'
      echo '    allow localhost'
      echo 'set logfile syslog'
      echo 'set eventqueue'
      echo '    basedir /var/run'
      echo '    slots 100'
      echo 'include /etc/monit.d/*'
} | tee /etc/monitrc

# Start monit
  find "/etc/monit.d" -maxdepth 4 -type f -exec sed -i -e 's|{{APP_DOCROOT}}|'"${APP_DOCROOT}"'|g' {} \;
  find "/etc/monit.d" -maxdepth 4 -type f -exec sed -i -e 's|{{CACHE_PREFIX}}|'"${CACHE_PREFIX}"'|g' {} \;
  find "/etc/monit.d" -maxdepth 4 -type f -exec sed -i -e 's|{{PHP_FPM_PORT}}|'"${PHP_FPM_PORT}"'|g' {} \;

  chmod 700 /etc/monitrc
  run="monit -c /etc/monitrc" && bash -c "${run}"

}

#---------------------------------------------------------------------
# make sure all permissions are set correctly for php-fpm
#---------------------------------------------------------------------

function permissions() {

    echo "Setting ownership and permissions on APP_ROOT and CACHE_PREFIX... "

    # This assumes you are using the common www-data for your user and group in NGINX and PHP-FPM. If you are using different users this is usually a recipe for error.

    find ${APP_DOCROOT} ! -user www-data -exec /usr/bin/env bash -c 'i="$1"; chown www-data:www-data "$i"' _ {} \;
    find ${APP_DOCROOT} ! -perm 755 -type d -exec /usr/bin/env bash -c 'i="$1"; chmod 755  "$i"' _ {} \;
    find ${APP_DOCROOT} ! -perm 644 -type f -exec /usr/bin/env bash -c 'i="$1"; chmod 644 "$i"' _ {} \;
    find ${CACHE_PREFIX} ! -perm 755 -type d -exec /usr/bin/env bash -c 'i="$1"; chmod 755  "$i"' _ {} \;
    find ${CACHE_PREFIX} ! -perm 644 -type f -exec /usr/bin/env bash -c 'i="$1"; chmod 644 "$i"' _ {} \;

}

#---------------------------------------------------------------------
# run all the functions to start the services
#---------------------------------------------------------------------

function run() {

  php-fpm
  if [[ -z $REDIS_UPSTREAM ]]; then echo "OK: Redis is not present so we will not activate it"; else redis; fi
  monit
  if [[ ! -z $NGINX_APP_PLUGIN ]]; then install_plugin else echo "OK: No plugins will be activated"; fi
  #permissions
  echo "OK: All processes have completed. Service is ready..."
}

run

exec "$@"
