#!/bin/bash

# Задаем переменные:
TIME=`date +"%Y-%m-%d_%H-%M"`

# Пути к лог-файлу и точкам монтирования
LOG_FILE="/mnt/pgsql_restore.log"
MOUNT_POINT1="/mnt/backup/PgSql"

# Telegram Bot API параметры
TOKEN="22222222:111111111eejccLggbvO22222222"
CHAT_ID="111111111"

# Название скрипта для уведомлений
SCRIPT_NAME="Восстановление баз данных 1C8_PG_restore:"

# Функция для записи логов и отправки уведомлений
log_and_notify() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> $LOG_FILE
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id=$CHAT_ID -d text="$SCRIPT_NAME: $message" > /dev/null
}

# Функция для создания базы данных
create_db() {
    local dbname="$1"
    createdb -U postgres $dbname
    if [ $? -eq 0 ]; then
        log_and_notify "✅ База данных $dbname успешно создана."
    else
        log_and_notify "❌ Ошибка при создании базы данных $dbname."
    fi
}

# Функция для восстановления базы данных
restore_and_notify() {
    local dbname="$1"
    local dump_file="$2"
    gunzip -c $dump_file | psql -U postgres -d $dbname
    if [ $? -eq 0 ]; then
        log_and_notify "✅ База данных $dbname успешно восстановлена из дампа."
    else
        log_and_notify "❌ Ошибка при восстановлении базы данных $dbname из дампа."
    fi
}

# IP адреса компьютеров
HOST1="192.168.1.2"

# Проверка доступности хостов
ping -c 1 $HOST1 > /dev/null 2>&1
HOST1_STATUS=$?

# Если хост доступен
if [ $HOST1_STATUS -eq 0 ]; then
    log_and_notify "✅ Хост доступен, монтируем шары..."

    # Монтируем шары
    sudo mount -t cifs //192.168.1.2/Backup_data/PgSql $MOUNT_POINT1 -o username=user1,password=123,domain=workgroup,iocharset=utf8,file_mode=0777,dir_mode=0777
    MOUNT1_STATUS=$?

    # Если монтирование прошло успешно
    if [ $MOUNT1_STATUS -eq 0 ]; then
        log_and_notify "✅ Шара успешно примонтирована, начинаем процесс восстановления баз данных..."

        # Список баз данных
        declare -A databases
        databases=(
            ["bueks"]="$MOUNT_POINT1/everyday/bueks/$TIME-bueks.sql.gz"
            ["butmt"]="$MOUNT_POINT1/everyday/butmt/$TIME-butmt.sql.gz"
            ["buvfn"]="$MOUNT_POINT1/everyday/buvfn/$TIME-buvfn.sql.gz"
            # Добавьте сюда остальные базы данных, если необходимо
        )

        # Создаем базы данных и восстанавливаем из дампов
        for dbname in "${!databases[@]}"; do
            create_db "$dbname"
            restore_and_notify "$dbname" "${databases[$dbname]}"
        done

        log_and_notify "✅ Все базы данных успешно восстановлены."

        # Размонтируем шары
        log_and_notify "🔄 Выполняем отмонтирование..."
        sudo umount $MOUNT_POINT1
        log_and_notify "✅ Шара успешно отмонтирована."
    else
        log_and_notify "❌ Не удалось примонтировать шару."

        # Попытка размонтирования в случае частичного монтирования
        if mount | grep $MOUNT_POINT1 > /dev/null; then
            sudo umount $MOUNT_POINT1
        fi
    fi
else
    log_and_notify "❌ Хост недоступен."
fi
