#!/bin/bash
set -x

systemctl enable ssh
#Добавление репозиториев Astra Linux
cat <<EOL > /etc/apt/sources.list
#deb http://srvrepo.security.ru/repos/astra173/ 1.7_x86-64 main contrib non-free
deb http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.3/repository-base 1.7_x86-64 main non-free contrib
deb http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.3/repository-extended 1.7_x86-64 main contrib non-free
EOL
#Добавление репозиториев ALD Pro
cat <<EOL > /etc/apt/sources.list.d/aldpro.list
deb https://dl.astralinux.ru/aldpro/stable/repository-main/ 1.3.0 main
deb https://dl.astralinux.ru/aldpro/stable/repository-extended/ generic main
EOL
#Установка приоритетов репозиториев
cat <<EOL > /etc/apt/preferences.d/aldpro
Package: *
Pin: release n=generic
Pin-Priority: 900
EOL
# Скачать скрипт первого запуска
# необходимо заменить IP адрес на ваш сервер ОС
wget ftp://192.168.50.249/{PROFILE_UNIQ_NAME}/{FIRSTSTART_FILE_NAME} -O /usr/bin/firststart.sh
# Подготовка к запуске сервиса первого запуска ОС
cat <<EOL > /etc/systemd/system/firststart.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/firststart.sh start

[Install]
WantedBy=multi-user.target
EOL
# Запуск сервиса
chmod 774 /usr/bin/firststart.sh
systemctl enable firststart || true
