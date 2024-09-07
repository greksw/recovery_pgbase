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

# Функция для поиска самого свежего дампа и его восстановления
restore_latest_dump() {
    local dbname="$1"
    local backup_dir="$2"
    
    # Поиск самого свежего файла дампа
    local latest_dump=$(ls -t "$backup_dir"/*.sql.gz 2>/dev/null | head -n 1)
    
    if [ -z "$latest_dump" ]; then
        log_and_notify "❌ Для базы данных $dbname не найдено дампов в директории $backup_dir."
    else
        gunzip -c "$latest_dump" | psql -U postgres -d $dbname
        if [ $? -eq 0 ]; then
            log_and_notify "✅ База данных $dbname успешно восстановлена из дампа $latest_dump."
        else
            log_and_notify "❌ Ошибка при восстановлении базы данных $dbname из дампа $latest_dump."
        fi
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

        # Список баз данных и соответствующих директорий с дампами
        declare -A databases
        databases=(
            ["bueks"]="$MOUNT_POINT1/everyday/bueks"
            ["butmt"]="$MOUNT_POINT1/everyday/butmt"
            ["buvfn"]="$MOUNT_POINT1/everyday/buvfn"
            # Добавьте сюда остальные базы данных
        )

        # Создаем базы данных и восстанавливаем из последнего дампа
        for dbname in "${!databases[@]}"; do
            create_db "$dbname"
            restore_latest_dump "$dbname" "${databases[$dbname]}"
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
