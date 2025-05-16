#!/bin/bash

RLS_MESSAGES="messages/message_rls"
SPRO_MESSAGES="messages/message_spro"
ZRDN_MESSAGES="messages/message_zrdn"
KP_LOGS="logs/kp_logs"
RLS_LOGS="logs/rls"
SPRO_LOGS="logs/spro"
ZRDN_LOGS="logs/zrdn"

SHOOTED_TARGETS_ZRDN1="tmp/shooted_targets/zrdn1"
SHOOTED_TARGETS_ZRDN2="tmp/shooted_targets/zrdn2"
SHOOTED_TARGETS_ZRDN3="tmp/shooted_targets/zrdn3"

FILE_TO_RUN_ZRDN="./zrdn/zrdn.sh"
CONFIG_FILE_ZRDN="zrdn/config.yaml"
FILE_TO_RUN_RLS="./rls/rls.sh"
CONFIG_FILE_RLS="rls/config.yaml"

DETECTED_TARGETS_ZRDN="tmp/detected_targes/zrdn_logs"
DETECTED_TARGETS_RLS="tmp/detected_targes/rls_logs"

SPRO_AMMO_FILE="spro/ammo"
ZRDN1_AMMO_FILE="zrdn/ammo_ZRDN1"
ZRDN2_AMMO_FILE="zrdn/ammo_ZRDN2"
ZRDN3_AMMO_FILE="zrdn/ammo_ZRDN3"


echo "" > $KP_LOGS
echo "" > $RLS_LOGS
echo "" > $SPRO_LOGS
echo "" > $ZRDN_LOGS
echo "" > $RLS_MESSAGES
echo "" > $ZRDN_MESSAGES
echo "" > $SPRO_MESSAGES

BAD_NUM_PROC=0

DB_FILE="db/vko.db"

# Удаляем существующую базу данных
rm -f "$DB_FILE"

# Создаем таблицу
sqlite3 "$DB_FILE" <<EOF
CREATE TABLE targets (
        id TEXT,
        target_type TEXT,
        system TEXT,
        event TEXT,
        timestamp TEXT
    );
EOF


decryptMessage() {
	local fileContent=$1

	local savedChecksum=$(echo "$fileContent" | head -n1 | cut -d' ' -f1)
	local encryptedContent=$(echo "$fileContent" | cut -d' ' -f2-)

	local decryptedContent=$(echo -n "$encryptedContent" | base64 -d)

	local calculatedChecksum=$(echo -n "$decryptedContent" | sha256sum | cut -d' ' -f1)

	if [ "$savedChecksum" = "$calculatedChecksum" ]; then
		echo "$decryptedContent"
	else
		echo "`date` Ошибка контрольной суммы" >>"$KP_LOGS"
		return 1
	fi
}

checkAmmo() {
	while : 
  do
    if grep -qw "0" $SPRO_AMMO_FILE; then
      echo "10" > $SPRO_AMMO_FILE
      echo "`date` [SPRO] Пополнение боеприпаса" >> "$KP_LOGS"
    fi

    if grep -qw "0" $ZRDN1_AMMO_FILE; then
      echo "20" > $ZRDN1_AMMO_FILE
      echo "`date` [ZRDN1] Пополнение боеприпаса" >> "$KP_LOGS"
    fi

    if grep -qw "0" $ZRDN2_AMMO_FILE; then
      echo "20" > $ZRDN2_AMMO_FILE
      echo "`date` [ZRDN2] Пополнение боеприпаса" >> "$KP_LOGS"
    fi

    if grep -qw "0" $ZRDN3_AMMO_FILE; then
      echo "20" > $ZRDN3_AMMO_FILE
      echo "`date` [ZRDN3] Пополнение боеприпаса" >> "$KP_LOGS"
    fi

	done
}

receiveMessages() {
  while :
  do
  	# сообщения рлс
  	lastRlsData=`cat $RLS_MESSAGES | tail -n 1`
    if [ ${#lastRlsData} -gt 5 ]
    then
      decryptedRls=$(decryptMessage "$lastRlsData")
  	  if ! grep -F "$decryptedRls" "$KP_LOGS" 
  	  then
  	  	echo "$decryptedRls" >> "$KP_LOGS"

        time=$(echo "$decryptedRls" | grep -oP '^.*?(?=\s*\[)')
        sys=$(echo "$decryptedRls" | grep -oP '(?<=\[).*?(?=\])')
        id=$(echo "$decryptedRls" | grep -oP '(?<=ID:)[0-9a-f]+')
        x=$(echo "$decryptedRls" | grep -oP '(?<=X:)[0-9]+')
        y=$(echo "$decryptedRls" | grep -oP '(?<=Y:)[0-9]+')

        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO targets (id, target_type, system, event, timestamp) VALUES ('$id', 'b', '$sys', 'Обнаружение', '$time');"
  	  fi
    fi

  	# сообщения спро
  	lastSproData=`cat $SPRO_MESSAGES | tail -n 1`
    if [ ${#lastSproData} -gt 5 ]
    then
  	  decryptedSpro=$(decryptMessage "$lastSproData")
  	  if ! grep -F "$decryptedSpro" "$KP_LOGS" 
  	  then
  	  	echo "$decryptedSpro" >> "$KP_LOGS"

        time=$(echo "$decryptedSpro" | grep -oP '^.*?(?=\s*\[)')
        sys=$(echo "$decryptedSpro" | grep -oP '(?<=\[).*?(?=\])')
        id=$(echo "$decryptedSpro" | grep -oP '(?<=ID:)[0-9a-f]+')
        x=$(echo "$decryptedSpro" | grep -oP '(?<=X:)[0-9]+')
        y=$(echo "$decryptedSpro" | grep -oP '(?<=Y:)[0-9]+')

        event='Обнаружение'

        if [[ "$decryptedSpro" == *"Выстрел"* ]]; then
          event='Выстрел'
        elif [[ "$decryptedSpro" == *"Промах"* ]]; then
          event='Промах'
        elif [[ "$decryptedSpro" == *"поражен"* ]]; then
          event='Поражен'
        fi


        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO targets (id, target_type, system, event, timestamp) VALUES ('$id', 'b', '$sys', '$event', '$time');"
  	  fi
    fi


  	# сообщения зрдн
  	lastZrdnData=`cat $ZRDN_MESSAGES | tail -n 1`
    if [ ${#lastZrdnData} -gt 5 ]
    then
  	  decryptedZrdn=$(decryptMessage "$lastZrdnData")
  	  if ! grep -F "$decryptedZrdn" "$KP_LOGS" 
  	  then
  	  	echo "$decryptedZrdn" >> "$KP_LOGS"

        time=$(echo "$decryptedZrdn" | grep -oP '^.*?(?=\s*\[)')
        sys=$(echo "$decryptedZrdn" | grep -oP '(?<=\[).*?(?=\])')
        id=$(echo "$decryptedZrdn" | grep -oP '(?<=ID:)[0-9a-f]+')
        x=$(echo "$decryptedZrdn" | grep -oP '(?<=X:)[0-9]+')
        y=$(echo "$decryptedZrdn" | grep -oP '(?<=Y:)[0-9]+')

        event='Обнаружение'

        if [[ "$decryptedZrdn" == *"Выстрел"* ]]; then
          event='Выстрел'
        elif [[ "$decryptedZrdn" == *"Промах"* ]]; then
          event='Промах'
        elif [[ "$decryptedZrdn" == *"поражен"* ]]; then
          event='Поражен'
        fi

        type='s'
        if [[ "$decryptedZrdn" == *"ракета"* ]]; then
          type='r'
        fi

        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO targets (id, target_type, system, event, timestamp) VALUES ('$id', '$type', '$sys', '$event', '$time');"
  	  fi
    fi
  done
}

autoFailover() {
  while :
  do
    ps=`ps -eo args`
    psZrdn1=`echo $ps | grep -c "ZRDN1" | grep -v grep`
    psZrdn2=`echo $ps | grep -c "ZRDN2" | grep -v grep`
    psZrdn3=`echo $ps | grep -c "ZRDN3" | grep -v grep`
    psRls1=`echo $ps | grep -c "RLS1" | grep -v grep`
    psRls2=`echo $ps | grep -c "RLS2" | grep -v grep`
    psRls3=`echo $ps | grep -c "RLS3" | grep -v grep`

    if [[ $psZrdn1 == $BAD_NUM_PROC ]]
    then
      echo "`date` [ZRDN1] Работоспособность восстановлена" >> $KP_LOGS
      $FILE_TO_RUN_ZRDN $CONFIG_FILE_ZRDN "ZRDN1" $DETECTED_TARGETS_ZRDN $ZRDN_LOGS $SHOOTED_TARGETS_ZRDN1 $ZRDN_MESSAGES &
    fi
    if [[ $psZrdn2 == $BAD_NUM_PROC ]]
    then
      echo "`date` [ZRDN2] Работоспособность восстановлена" >> $KP_LOGS
      $FILE_TO_RUN_ZRDN $CONFIG_FILE_ZRDN "ZRDN2" $DETECTED_TARGETS_ZRDN $ZRDN_LOGS $SHOOTED_TARGETS_ZRDN2 $ZRDN_MESSAGES &
    fi
    if [[ $psZrdn3 == $BAD_NUM_PROC ]]
    then
      echo "`date` [ZRDN3] Работоспособность восстановлена" >> $KP_LOGS
      $FILE_TO_RUN_ZRDN $CONFIG_FILE_ZRDN "ZRDN3" $DETECTED_TARGETS_ZRDN $ZRDN_LOGS $SHOOTED_TARGETS_ZRDN3 $ZRDN_MESSAGES &
    fi

    if [[ $psRls1 == $BAD_NUM_PROC ]]
    then
      echo "`date` [RLS1] Работоспособность восстановлена" >> $KP_LOGS
      $FILE_TO_RUN_RLS $CONFIG_FILE_RLS 'RLS1' $DETECTED_TARGETS_RLS $RLS_LOGS $RLS_MESSAGES &
    fi
    if [[ $psRls2 == $BAD_NUM_PROC ]]
    then
      echo "`date` [RLS2] Работоспособность восстановлена" >> $KP_LOGS
      $FILE_TO_RUN_RLS $CONFIG_FILE_RLS 'RLS2' $DETECTED_TARGETS_RLS $RLS_LOGS $RLS_MESSAGES &
    fi
    if [[ $psRls3 == $BAD_NUM_PROC ]]
    then
      echo "`date` [RLS3] Работоспособность восстановлена" >> $RLS_LOGS
      $FILE_TO_RUN_RLS $CONFIG_FILE_RLS 'RLS3' $DETECTED_TARGETS_RLS $RLS_LOGS $RLS_MESSAGES &
    fi
  done
}

checkAmmo &
receiveMessages &
autoFailover &

# завершение дочерних процессов
parentPid=$$
cleanup() {
  pkill -P $parentPid
}
trap cleanup EXIT
wait
