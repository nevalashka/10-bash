#!/bin/bash
#BEGIN VARIABLE REGION
LOCK_OBJECT="./lock.obj"
SOURCE_LOG="./access-4560-644067.log"
WORK_LOG="./worklog.log"
MAIL_MESSAGE="./message.txt"
MAGIC_SEQUENCE="TIMESTAMP"
START_STRING=""
#END VARIABLE REGION

#BEGIN FUNCTION REGION
function GetDateRange()
    {
        CURRENT_DATE=$(LANG=en_us_88591; date +" %d/%b/%Y:%H:%M:%S")
        echo "Начало работы скрипта: [${CURRENT_DATE:1}]" > "$MAIL_MESSAGE"
        DATE_BEGIN=$(head -n 1 "$WORK_LOG" | awk -F " " '{print $4}')
        DATE_END=$(tail -1 "$WORK_LOG" | awk -F " " '{print $4}') 
        echo "Лог анализировался в следующем временном промежутке: [${DATE_BEGIN:1} ==> ${DATE_END:1}]" \
        >> "$MAIL_MESSAGE"
    }

function GetListIP() 
    {
        echo -e "\n\n 1. Список IP Адресов с наибольшим количеством запросов (top-15): \n"  >> "$MAIL_MESSAGE"
        cat $WORK_LOG | awk '{print $1}' | sort | uniq -c | \
        sort -nr | head -n 15 >> "$MAIL_MESSAGE"
    }

function GetListURL() 
    {
        echo -e "\n\n 2. Список запрашиваемых URL (top-20): \n" >> "$MAIL_MESSAGE"
        awk -F\" '{print $2}' "$WORK_LOG" | awk '{print $2}' | \
        sort | uniq -c | sort -nr | head -n 20 >> "$MAIL_MESSAGE"
    }

function GetWebServerErrors()
    {
        echo -e "\n\n 3. Ошибки веб-сервера: \n" >> "$MAIL_MESSAGE"
        cat "$WORK_LOG" | grep -E '" 50?' >> "$MAIL_MESSAGE"   
    }

function GetResponsesCodes()
    {
       echo -e "\n\n 4. Список всех кодов HTTP ответа: \n" >> "$MAIL_MESSAGE"
       cat "$WORK_LOG" | cut -d '"' -f3 | cut -d ' ' -f2 |  \
       sort | uniq -c | sort -rn >> "$MAIL_MESSAGE"
    }
#END FUNCTION REGION

#BEGIN SCRIPT BODY REGION
if [ -e $LOCK_OBJECT ]
    then
    echo "Script is already running..."
    exit 0
else
    touch "$LOCK_OBJECT"
    trap 'rm -f "$LOCK_OBJECT" "$WORK_LOG"' 0
    # Ищем наличие временной метки в логе:
    START_STRING=$(grep -m 1 -rnw "$SOURCE_LOG" -e "^$MAGIC_SEQUENCE" | awk -F":" '{print $1}')

    if [[ -z $START_STRING ]]
        then
            cp "$SOURCE_LOG" "$WORK_LOG"
            # Удаление пустых строк:
            sed -i '/^$/d' "$WORK_LOG"
            # Ставим временную метку с последний запуском в скрипта:
            echo "${MAGIC_SEQUENCE}$(LANG=en_us_88591; date +" %d/%b/%Y:%H:%M:%S")" >> "$SOURCE_LOG"
        else
            # Удаляем последнюю временную метку:
            sed  -i "$START_STRING"d "$SOURCE_LOG"
            # Пишем всё от метки до конца файла во временный файл для анализа:
            tail -n +$START_STRING "$SOURCE_LOG" > "$WORK_LOG"
            # Удаление пустых строк:
            sed -i '/^$/d' "$WORK_LOG" 
            # Ставим временную метку с последний запуском в скрипта:
            echo "${MAGIC_SEQUENCE}$(LANG=en_us_88591; date +" %d/%b/%Y:%H:%M:%S")" >> "$SOURCE_LOG"
    fi

    GetDateRange
    GetListIP
    GetListURL
    GetWebServerErrors
    GetResponsesCodes

    mail -s "Анализ лога NGINX" user@domain.ru < $MAIL_MESSAGE

    exit 0
fi
#END SCRIPT BODY REGION
