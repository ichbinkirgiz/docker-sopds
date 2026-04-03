Запускает в докере <a href="https://github.com/ichbinkirgiz/sopds">вот этот</a> SOPDS каталог через nginx.
Спасибо [@deathmond1987](https://github.com/deathmond1987)

Перед созданием контейнера рекомендую создать volume для хранения базы данных.

```
docker volume create mysopds_pgsql
```

В принципе volume создаётся автоматически, но в имени будет какая-нибудь кракозябра типа acdd9b749659c351a1d2601a08fa784c9c4b.
При большом количестве разных контейнеров говорящие названия удобней imho.


Затем запускаем контейнер:

```
docker run -d --name mysopds \
    --publish 8001:80 \
    --env TIME_ZONE="Europe/Berlin" \ 
    --volume /path/to/library:/library:ro \
    --volume mysopds_pgsql:/var/lib/pgsql \
    ichbinkirgiz/sopds:nginx
```
> [!WARNING]
> При первом запуске контейнера, даже если у вас был свой volume с готовой коллекцией книг, эта коллекция будет стёрта.

Иначе не будут работать русифицированные жанры и аннотации книг. Сканирование коллекции происходит быстро, так что не бойтесь.

Кроме того контейнер создаст свой уникальный SECRET_KEY, а то юзаем один ключ на всех.<br>
Поскольку запустили nginx, DEBUG = False.

По умолчанию в контейнере устанавливается московское время. Если есть необходимость поменять,
укажите желаемый часовой пояс в переменной --env TIME_ZONE="Europe/Berlin"
.[Тётя Вика вам в помощь.](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List)

**===================================================================================**

# Introduction

Dockerfile to build a Simple OPDS server docker image.
http://www.sopds.ru

# Installation

Pull the latest version of the image from the docker.

```
docker pull zveronline/sopds
```

Alternately you can build the image yourself.

```
docker build -t zveronline/sopds https://github.com/zveronline/docker-sopds.git
```

# Quick Start

Run the image

```
docker run --name sopds -d \
   --volume /path/to/library:/library:ro \
   --publish 8001:8001 \
   zveronline/sopds
```

This will start the sopds server and you should now be able to browse the content on port 8081.

```
docker run --name sopds -d \
   --volume /path/to/library:/library:ro \
   --volume /path/to/database:/var/lib/pgsql \
   --publish 8001:8001 \
   zveronline/sopds
```

Also you can store postgresql database on external storage.

```
docker run --name sopds -d \
   --volume /path/to/library:/library:ro \
   --env 'DB_USER=sopds' \
   --env 'DB_NAME=sopds' \
   --env 'DB_PASS=sopds' \
   --env 'DB_HOST=""' \
   --env 'DB_PORT=""' \
   --env 'EXT_DB=True' \
   --publish 8001:8001 \
   zveronline/sopds
```


# Create superuser

By default the superuser will be created with predefined name "admin" and password "admin". But you can manage it via appropriate environmental variables:
```bash
docker run --name sopds -d \
   --volume /path/to/library:/library:ro \
   --volume /path/to/database:/var/lib/pgsql \
   --env 'SOPDS_SU_NAME="your_name_for_superuser"' \
   --env 'SOPDS_SU_EMAIL='"your_mail_for_superuser@your_domain"' \
   --env 'SOPDS_SU_PASS="your_password_for_superuser"' \
   --publish 8001:8001 \
   zveronline/sopds
```

# Scan library

```bash
docker exec -ti sopds bash
python3 manage.py sopds_util setconf SOPDS_SCAN_START_DIRECTLY True
```

# Autostart of the SOPDS Telegram-bot

By default the Telegram-bot isn't enabled. But you can configure it to be started with container start at any time. 
```bash
docker run --name sopds -d \
   --volume /path/to/library:/library:ro \
   --volume /path/to/database:/var/lib/pgsql \
   --env 'SOPDS_TMBOT_ENABLE="True"' \
   --publish 8001:8001 \
   zveronline/sopds
```
Please don't forget to configure the bot itself via interface of SOPDS.
