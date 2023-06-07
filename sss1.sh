#!/bin/bash
# функция информирования о ходе установки скрипта. Первый аргумент - какой этап скрипта выполняется
info () {
        echo ">-----Выполняется: $1"
        echo -e "\n---###############---Выполняется: $1\n" >> .log
        sleep 1
}

# записываем изменения, которые внесли в файл, если указан путь первым аргументом
infok () { 
        if [[ $1 ]]; then
                echo -e "Содержание измененного файла $1:\n" >> .log
                cat $1 >> .log
        fi

        echo -e "\n>-----OK\n" 
        echo -e "\n-------OK\n" >> .log
}

# проверяем наличие конфигурационного файла для ALDPRO. Если есть, значит первый этап установки был выполнел (часть скрипа, которая 
# выполнилась, при условии что этого файла не было). Если файл есть, то выполняется часть скрипа после else 
RES=""
if [[ ! -f /etc/apt/preferences.d/aldpro ]]; then 

        read -p "Введите имя хоста: " HSTNAME
        read -p "Введите IP текущего хоста: " HOSTIP
        read -p "Введите gateway: " GATEWAY
        read -p "Введите IP address dns server: " DNSIP
        read -p "Введите IP домен контроллера: " DCIP
        read -p "Введите имя домена: " DOMAIN
        read -p "Введите пароль для админа контреоллера домена: " PASSWORD
        read -p "Настройка домена или ввод хоста в домен? D-домен, H-хост: " ACT
        #read -p "Введите имя сетевого интерфейса: " NETWNAME
        #read -p "Введите версию AstraLinux в формате х.х.х " ALVERSION
        #read -p "Введите версию AldPRO в формате х.х.х " ALDPROVERSION

# проверяем какое дейстивие введено - настройка домена или ввод хоста в домен
        if [[ $ACT != "H" ]]; then
                while [[ $ACT != "D" ]]
                do
                        read -p "Enter D or H :" ACT
                        if [[ $ACT == "H" ]]; then
                        break
        fi
                done
        fi

# выводим введённые данные для проверки
        echo -e "\nhostname: $HSTNAME\nIP address: $HOSTIP\ngameway: $GATEWAY\ndns IP address: $DNSIP\nIP address DC: $DCIP\ndomain: $DOMAIN\npassword: $PASSWORD\nНастройка домена(D) или хоста(H): $ACT\n"

        read -p "Данные введены корректно ? " RES

# сохраняем введённые данные для второго этапа установки скрипта
cat <<EOF > .varForDCstp
export HSTNAME=$HSTNAME
export HOSTIP=$HOSTIP
export GATEWAY=$GATEWAY
export DNSIP=$DNSIP
export DOMAIN=$DOMAIN
export PASSWORD=$PASSWORD
export ACT=$ACT
export DCIP=$DCIP
EOF

# изменяем hostname
        info "изменяем hostname"
        echo "$HSTNAME.$DOMAIN" > /etc/hostname
        infok /etc/hostname

# изменяем hosts
        info "изменяем hosts"
        IFS=" "
        SH=$(tail -n 5 /etc/hosts)
cat <<EOF > /etc/hosts
127.0.0.1       localhost.localdomain   localhost
$HOSTIP         $HSTNAME.$DOMAIN       $HSTNAME
127.0.1.1       $HSTNAME
EOF
        echo $SH >> /etc/hosts
        infok /etc/hosts

# добавляем репозитории Astra Linux
        #while IFS= read -r line
        #do
        #       echo "#$line" >> /etc/apt/sources.list
        #done < /etc/apt/sources.list

        info "добавляем репозитории Astra Linux"
        echo -e "\ndeb http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.3/repository-base 1.7_x86-64 main non-free contrib" | sudo tee /etc/apt/sources.list
        echo -e "deb http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.3/repository-extended 1.7_x86-64 main contrib non-free" | sudo tee -a /etc/apt/sources.list
        infok /etc/apt/sources.list

# добавляем репоизтории ALDPRO
        info "добавляем репоизтории ALDPRO"
        echo "deb https://download.astralinux.ru/aldpro/stable/repository-main/ 1.3.0 main" >> /etc/apt/sources.list.d/aldpro.list
        echo "deb https://download.astralinux.ru/aldpro/stable/repository-extended/ generic main" >> /etc/apt/sources.list.d/aldpro.list
        infok /etc/apt/sources.list.d/aldpro.list

# добавляем конфигурационный файл для ALDPRO
        info "добавляем конфигурационный файл для ALDPRO"
cat <<EOF > /etc/apt/preferences.d/aldpro
Package: *
Pin: release n=generic
Pin-Priority: 900
EOF
        infok /etc/apt/preferences.d/aldpro

# обновляем пакеты из репозиториев
        info "обновляем пакеты из репозиториев"
        echo -e "\n"
        sudo apt update && sudo apt dist-upgrade -y  #&>> .log 
        infok

# отключаем службу network-manager
        info "отключаем службу network-manager"
        echo -e "\n"
        stp="stop"
        sudo systemctl $stp network-manager  #&>> .log
        sudo systemctl disable network-manager  #&>> .log
        infok

# изменяем конфигурационный файл interfaces домена контроллера
if [[ $ACT == "D" ]]; then
        info "изменяем конфигурационный файл interfaces для DC"
cat <<EOF >> /etc/network/interfaces
auto eth0
iface eth0 inet static
    address $HOSTIP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers $DNSIP
    dns-search $DOMAIN
EOF
        infok /etc/network/interfaces

# изменяем конфигурационный файл хоста при вводе в домен
else
        info "изменяем конфигурационный файл interfaces при вводе в DC"
cat <<EOF >> /etc/network/interfaces
auto eth0
iface eth0 inet static
    address $HOSTIP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers $DCIP
    dns-search $DOMAIN
EOF
        infok /etc/network/interfaces
fi

# изменяем конфигурационный файл resolv при вводе хоста в домен
        if [[ $ACT == "H" ]]; then
                info "изменяем конфигурационный файл resolv при вводе в DC"
                echo "nameserver $DCIP" > /etc/resolv.conf
                echo "search $DOMAIN" >> /etc/resolv.conf
                infok /etc/resolv.conf
        fi

# информационное сообщение перед перезагрузкой
        read -p "Перезагрузите компьютер. Запустите скрипт снова из той же папки!" RES
        #read -p "Перезагрузите компьютер. Запустите скрипт снова из той же папки! Логи сохраняются в папке со скриптом файл .log" RES
        exit




else     ######################----- ВТОРОЙ ЭТАП УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ -----######################
        echo -e "\n>-------ВТОРОЙ ЭТАП УСТАНОВКИ ПОСЛЕ ПЕРЕЗАГРУЗКИ-------<" >> .log
# восстанавливаем нужные данные из временного файла введённые при первом запуске скрипта.
        source .varForDCstp

# устанавливаем необходимые пакеты для ALDPRO
        if [[ $ACT == "D" ]]; then
                info "устанавливаем необходимые пакеты для ALDPRO для DC"
                echo -e "\n"
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y aldpro-mp
                infok 

# устанавливаем необходимые пакеты для хоста при вводе в домен (клиент)
        else
                info "устанавливаем необходимые пакеты для ALDPRO при вводе хоста в домен"
                echo -e "\n"
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y aldpro-client
                infok 
        fi

# изменяем в interfaces dns-nameservers на 127.0.0.1 при настройке контроллера домена
        if [[ $ACT == "D" ]]; then
                info "изменяем в interfaces dns-nameservers на 127.0.0.1 для DC"
                IFS=" "
                str=$(cat /etc/network/interfaces)
                res=${str//dns-nameservers $DNSIP/dns-nameservers 127.0.0.1}
                echo $res > /etc/network/interfaces
                sudo systemctl restart networking  #&>> .log
                infok /etc/network/interfaces
        fi

# изменяем конфигурационный файл resolv при настройке контроллера домена
        if [[ $ACT == "D" ]]; then
                info "изменяем конфигурационный файл resolv для DC"
                echo "nameserver 127.0.0.1" > /etc/resolv.conf
                echo "search $DOMAIN" >> /etc/resolv.conf
                infok /etc/resolv.conf
        fi

# выполняем настройку контроллера домена
        if [[ $ACT == "D" ]]; then
                info "выполняем настройку контроллера домена"
                echo -e "\n"
                sudo /opt/rbta/aldpro/mp/bin/aldpro-server-install.sh -d $DOMAIN -n $HSTNAME -p $PASSWORD --ip $HOSTIP --no-reboot
                infok

# выполняем ввод хоста в домен
        else
                info "выполняем настройку хоста для ввода в домен"
                echo -e "\n"
                sudo /opt/rbta/aldpro/client/bin/aldpro-client-installer -c $DOMAIN -u admin -p $PASSWORD -d $HSTNAME -i -f
                infok
        fi
# удаляем временные файлы
#rm .varForDCstp

# последнее информационное сообщение при настройке контроллера домена 
        if [[ $ACT == "D" ]]; then
                echo "Введённые данные содержаться в файле .varForDCstp, который находится в папке со скриптом."
                echo "Содержание изменённых файлов и ход выполнения скрипта содержатся в файле .log, который находится в папке со скриптом."
                read -p "Перезагрузите компьютер. Доступ к админке через браузер (https://$HSTNAME.$DOMAIN) " RES

# последнее информационное сообщение при вводе хоста в домен
        else
                echo "Введённые данные содержаться в файле .varForDCstp, который находится в папке со скриптом."
                echo "Содержание изменённых файлов и ход выполнения скрипта содержатся в файле .log, который находится в папке со скриптом."
                read -p "Перезагрузите компьютер. Залогинтесь под зарегистрированным пользователем " RES
        fi

fi
