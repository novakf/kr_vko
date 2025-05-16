#!/bin/bash

rls_messages="messages/message_rls"
spro_messages="messages/message_spro"
zrdn_messages="messages/message_zrdn"
kp_logs="logs/kp_logs"
rls_logs="logs/rls"
spro_logs="logs/spro"
zrdn_logs="logs/zrdn"

temp_file1="temp/temp/zrdn1"
temp_file2="temp/temp/zrdn2"
temp_file3="temp/temp/zrdn3"

file_to_run_zrdn="./zrdn/zrdn.sh"
config_file_zrdn="zrdn/config.yaml"
file_to_run_rls="./rls/rls.sh"
config_file_rls="rls/config.yaml"

file_log_zrdn="temp/logs/zrdn_logs"
file_log_rls="temp/logs/rls_logs"

spro_ammo_file="spro/ammo"
zrdn1_ammo_file="zrdn/ammo_ZRDN1"
zrdn2_ammo_file="zrdn/ammo_ZRDN2"
zrdn3_ammo_file="zrdn/ammo_ZRDN3"


echo "" > $kp_logs
echo "" > $rls_logs
echo "" > $spro_logs
echo "" > $zrdn_logs
echo "" > $rls_messages
echo "" > $zrdn_messages
echo "" > $spro_messages

bad_num_proc=0
check_systems_time=10

DB_FILE="db/vko.db"

# Удаляем существующую базу данных (если нужно)
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
	local file_content=$1

	local saved_checksum=$(echo "$file_content" | head -n1 | cut -d' ' -f1)
	local encrypted_content=$(echo "$file_content" | cut -d' ' -f2-)

	local decrypted_content=$(echo -n "$encrypted_content" | base64 -d)

	local calculated_checksum=$(echo -n "$decrypted_content" | sha256sum | cut -d' ' -f1)

	if [ "$saved_checksum" = "$calculated_checksum" ]; then
		echo "$decrypted_content"
	else
		echo "`date` Ошибка контрольной суммы" >>"$kp_logs"
		return 1
	fi
}

checkAmmo() {
	while : 
  do
    if grep -qw "0" $spro_ammo_file; then
      echo "10" > $spro_ammo_file
      echo "`date` [SPRO] Пополнение боеприпаса" >> "$kp_logs"
    fi

    if grep -qw "0" $zrdn1_ammo_file; then
      echo "20" > $zrdn1_ammo_file
      echo "`date` [ZRDN1] Пополнение боеприпаса" >> "$kp_logs"
    fi

    if grep -qw "0" $zrdn2_ammo_file; then
      echo "20" > $zrdn2_ammo_file
      echo "`date` [ZRDN2] Пополнение боеприпаса" >> "$kp_logs"
    fi

    if grep -qw "0" $zrdn3_ammo_file; then
      echo "20" > $zrdn3_ammo_file
      echo "`date` [ZRDN3] Пополнение боеприпаса" >> "$kp_logs"
    fi

	done
}

receiveMessages() {
  while :
  do
  	# сообщения рлс
  	last_rls_data=`cat $rls_messages | tail -n 1`
    if [ ${#last_rls_data} -gt 5 ]
    then
      decrypted_rls=$(decryptMessage "$last_rls_data")
  	  if ! grep -F "$decrypted_rls" "$kp_logs" 
  	  then
  	  	echo "$decrypted_rls" >> "$kp_logs"

        time=$(echo "$decrypted_rls" | grep -oP '^.*?(?=\s*\[)')
        sys=$(echo "$decrypted_rls" | grep -oP '(?<=\[).*?(?=\])')
        id=$(echo "$decrypted_rls" | grep -oP '(?<=ID:)[0-9a-f]+')
        x=$(echo "$decrypted_rls" | grep -oP '(?<=X:)[0-9]+')
        y=$(echo "$decrypted_rls" | grep -oP '(?<=Y:)[0-9]+')

        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO targets (id, target_type, system, event, timestamp) VALUES ('$id', 'b', '$sys', 'Обнаружение', '$time');"
  	  fi
    fi

  	# сообщения спро
  	last_spro_data=`cat $spro_messages | tail -n 1`
    if [ ${#last_spro_data} -gt 5 ]
    then
  	  decrypted_spro=$(decryptMessage "$last_spro_data")
  	  if ! grep -F "$decrypted_spro" "$kp_logs" 
  	  then
  	  	echo "$decrypted_spro" >> "$kp_logs"

        time=$(echo "$decrypted_spro" | grep -oP '^.*?(?=\s*\[)')
        sys=$(echo "$decrypted_spro" | grep -oP '(?<=\[).*?(?=\])')
        id=$(echo "$decrypted_spro" | grep -oP '(?<=ID:)[0-9a-f]+')
        x=$(echo "$decrypted_spro" | grep -oP '(?<=X:)[0-9]+')
        y=$(echo "$decrypted_spro" | grep -oP '(?<=Y:)[0-9]+')

        event='Обнаружение'

        if [[ "$decrypted_spro" == *"Выстрел"* ]]; then
          event='Выстрел'
        elif [[ "$decrypted_spro" == *"Промах"* ]]; then
          event='Промах'
        elif [[ "$decrypted_spro" == *"поражен"* ]]; then
          event='Поражен'
        fi


        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO targets (id, target_type, system, event, timestamp) VALUES ('$id', 'b', '$sys', '$event', '$time');"
  	  fi
    fi


  	# сообщения зрдн
  	last_zrdn_data=`cat $zrdn_messages | tail -n 1`
    if [ ${#last_zrdn_data} -gt 5 ]
    then
  	  decrypted_zrdn=$(decryptMessage "$last_zrdn_data")
  	  if ! grep -F "$decrypted_zrdn" "$kp_logs" 
  	  then
  	  	echo "$decrypted_zrdn" >> "$kp_logs"

        time=$(echo "$decrypted_zrdn" | grep -oP '^.*?(?=\s*\[)')
        sys=$(echo "$decrypted_zrdn" | grep -oP '(?<=\[).*?(?=\])')
        id=$(echo "$decrypted_zrdn" | grep -oP '(?<=ID:)[0-9a-f]+')
        x=$(echo "$decrypted_zrdn" | grep -oP '(?<=X:)[0-9]+')
        y=$(echo "$decrypted_zrdn" | grep -oP '(?<=Y:)[0-9]+')

        event='Обнаружение'

        if [[ "$decrypted_zrdn" == *"Выстрел"* ]]; then
          event='Выстрел'
        elif [[ "$decrypted_zrdn" == *"Промах"* ]]; then
          event='Промах'
        elif [[ "$decrypted_zrdn" == *"поражен"* ]]; then
          event='Поражен'
        fi

        type='s'
        if [[ "$decrypted_zrdn" == *"ракета"* ]]; then
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
    ps_zrdn1=`echo $ps | grep -c "ZRDN1" | grep -v grep`
    ps_zrdn2=`echo $ps | grep -c "ZRDN2" | grep -v grep`
    ps_zrdn3=`echo $ps | grep -c "ZRDN3" | grep -v grep`
    ps_rls1=`echo $ps | grep -c "RLS1" | grep -v grep`
    ps_rls2=`echo $ps | grep -c "RLS2" | grep -v grep`
    ps_rls3=`echo $ps | grep -c "RLS3" | grep -v grep`

    if [[ $ps_zrdn1 == $bad_num_proc ]]
    then
      echo "`date` [ZRDN1] Работоспособность восстановлена" >> $kp_logs
      $file_to_run_zrdn $config_file_zrdn "ZRDN1" $file_log_zrdn $zrdn_logs $temp_file1 $zrdn_messages &
    fi
    if [[ $ps_zrdn2 == $bad_num_proc ]]
    then
      echo "`date` [ZRDN2] Работоспособность восстановлена" >> $kp_logs
      $file_to_run_zrdn $config_file_zrdn "ZRDN2" $file_log_zrdn $zrdn_logs $temp_file2 $zrdn_messages &
    fi
    if [[ $ps_zrdn3 == $bad_num_proc ]]
    then
      echo "`date` [ZRDN3] Работоспособность восстановлена" >> $kp_logs
      $file_to_run_zrdn $config_file_zrdn "ZRDN3" $file_log_zrdn $zrdn_logs $temp_file3 $zrdn_messages &
    fi

    if [[ $ps_rls1 == $bad_num_proc ]]
    then
      echo "`date` [RLS1] Работоспособность восстановлена" >> $kp_logs
      $file_to_run_rls $config_file_rls 'RLS1' $file_log_rls $rls_logs $rls_messages &
    fi
    if [[ $ps_rls2 == $bad_num_proc ]]
    then
      echo "`date` [RLS2] Работоспособность восстановлена" >> $kp_logs
      $file_to_run_rls $config_file_rls 'RLS2' $file_log_rls $rls_logs $rls_messages &
    fi
    if [[ $ps_rls3 == $bad_num_proc ]]
    then
      echo "`date` [RLS3] Работоспособность восстановлена" >> $rls_logs
      $file_to_run_rls $config_file_rls 'RLS3' $file_log_rls $rls_logs $rls_messages &
    fi
  done
}

checkAmmo &
receiveMessages &
autoFailover &

# завершение дочерних процессов
parent_pid=$$
cleanup() {
  pkill -P $parent_pid
}
trap cleanup EXIT
wait
