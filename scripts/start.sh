#!/usr/bin/env ash

waiting_db(){
while ! pg_isready -U postgres > /dev/null; do
    echo "$(date) - waiting for database to start"
    cat /var/lib/pgsql/data/pg.log
    sleep 10
done
}

if ! [ -d /run/postgresql ]; then
    mkdir -p /run/postgresql
    chown -R postgres:postgres /run/postgresql
fi

if [[ $EXT_DB == False && ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
    chown -R postgres:postgres /var/lib/pgsql
    chmod -R 0700 /var/lib/pgsql
    su postgres -c "/usr/bin/pg_ctl -D /var/lib/pgsql/data initdb"
    su postgres -c "/usr/bin/pg_ctl -D /var/lib/pgsql/data start"
    waiting_db
    psql -U postgres -c "create database sopds"
    psql -U postgres -c "create user sopds with password 'sopds'"
    psql -U postgres -c "grant all privileges on database sopds to sopds"
    cd /sopds
    python3 manage.py migrate
    su postgres -c "/usr/bin/pg_ctl -D /var/lib/pgsql/data stop"
fi
if [ $EXT_DB == False ]; then
    su postgres -c "/usr/bin/pg_ctl -D /var/lib/pgsql/data start"
    waiting_db
fi
cd /sopds
if [ $MIGRATE == True ]; then
    python3 manage.py migrate
fi
if [ ! -f /var/lib/pgsql/setconf ]; then
    python3 manage.py sopds_util setconf SOPDS_ROOT_LIB $SOPDS_ROOT_LIB
    python3 manage.py sopds_util setconf SOPDS_INPX_ENABLE $SOPDS_INPX_ENABLE
    python3 manage.py sopds_util setconf SOPDS_LANGUAGE $SOPDS_LANGUAGE

    #configure fb2converter for epub and mobi - https://github.com/rupor-github/fb2converter
    python3 manage.py sopds_util setconf SOPDS_FB2TOEPUB "convert/fb2c/fb2epub"
    python3 manage.py sopds_util setconf SOPDS_FB2TOMOBI "convert/fb2c/fb2mobi"

    #autocreate the superuser
    if [[ ! -z $SOPDS_SU_NAME && ! -z $SOPDS_SU_EMAIL &&  ! -z $SOPDS_SU_PASS ]]; then
        expect /sopds/superuser.exp
    fi
    python3 manage.py sopds_util clear
    touch /var/lib/pgsql/setconf
fi

super_dir=/etc
super_conf="$super_dir"/supervisord.conf
if [ ! -f "$super_conf" ]; then
    echo -e "  supervisor config not found. Creating config..."
    mkdir -p "$super_dir"
    echo -e '#[unix_http_server]

    [supervisord]
    user=root
    pidfile=/var/run/supervisord.pid
    stdout_logfile=/dev/stdout
    stdout_logfile_maxbytes=0
    stderr_logfile=/dev/stdout
    stderr_logfile_maxbytes=0
    loglevel=info

    [rpcinterface:supervisor]
    supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

    [supervisorctl]
    serverurl=unix:///var/run/supervisor.sock
    [program:sopds_server]
    command=ash -c "wait_pg.sh && python3 manage.py sopds_server start"
#    user=www-data
    autostart=true
    autorestart=true
    stdout_logfile=/dev/stdout
    stdout_logfile_maxbytes=0
    stderr_logfile=/dev/stdout
    stderr_logfile_maxbytes=0
    depends_on=postgresql

    [program:nginx]
    command=nginx -c /etc/nginx/nginx.conf -g "daemon off;"
    stdout_logfile=/dev/stdout
    stdout_logfile_maxbytes=0
    stderr_logfile=/dev/stdout
    stderr_logfile_maxbytes=0
    autostart=true
    autorestart=true

    [program:sopds_scanner]
    command=ash -c "wait_pg.sh && python3 manage.py sopds_scanner start"
    autostart=true
    autorestart=true

    [program:postgresql]
    command=/usr/bin/postgres -D /var/lib/pgsql/data
    stopsignal=INT
    user=postgres
    autostart=true
    autorestart=true
    stdout_logfile=/dev/stdout
    stdout_logfile_maxbytes=0
    stderr_logfile=/dev/stdout
    stderr_logfile_maxbytes=0' > "$super_conf"
fi
#To start the Telegram-bot if it enabled
if [ "$SOPDS_TMBOT_ENABLE" == "True" ]; then
    echo -e "  telegram enabled in variable..."
    if ! grep -q "telegram" "$super_conf"; then
    echo -e "  telegram config not found in $super_conf. Creating..."
    echo -e '[program:sopds_telegram]
    command=ash -c "wait_pg.sh && python3 manage.py sopds_telebot start"
    autostart=true' >> "$super_conf"
    fi
fi

if [ -n "$SOPDS_TELEBOT_API_TOKEN" ]; then
    echo -e "  telegram api token variable found. Adding token in app..."
    python3 manage.py sopds_util setconf SOPDS_TELEBOT_API_TOKEN "$SOPDS_TELEBOT_API_TOKEN" >/dev/null 2>&1
fi

waitdbfile="/usr/bin/wait_pg.sh"
if [ ! -f "$waitdbfile" ]; then
    echo -e 'while ! pg_isready -U postgres > /dev/null; do
          echo "$(date) - waiting for database to start"
          sleep 2
          done' > "$waitdbfile"
    chmod 700 "$waitdbfile"
fi

if [ -n "$SOPDS_TELEGRAM_USER_NAME" ]; then
    echo -e "  telegram user name variable found. Adding telegram username $SOPDS_TELEGRAM_USER_NAME to sopds database..."
    python manage.py createsuperuser --username "$SOPDS_TELEGRAM_USER_NAME" --noinput --email "$SOPDS_TELEGRAM_USER_NAME"@gmail.com >/dev/null 2>&1 || true
fi

su postgres -c "/usr/bin/pg_ctl -D /var/lib/pgsql/data -l /dev/stdout stop"
echo -e "  Configuration finished. Starting app..."

exec "$@"
