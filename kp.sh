#!/bin/bash

rls_messages="messages/message_rls"
spro_messages="messages/message_spro"
zrdn_messages="messages/message_zrdn"
kp_logs="logs/kp_logs"
rls_logs="logs/rls"
spro_logs="logs/spro"
zrdn_logs="logs/zrdn"

file_to_run_zrdn="./zrdn/zrdn.sh"
config_file_rdn="zrdn/config.yaml"
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

DB_FILE="$db/vko.db"

# Создание базы данных и таблиц, если они не существуют
initializeDatabase() {
	if [[ -f "$DB_FILE" ]]; then
		echo "База данных существует, удаляем"
		rm -f "$DB_FILE"
	fi

	sqlite3 "$DB_FILE" <<EOF
    CREATE TABLE IF NOT EXISTS detections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target TEXT,
        system TEXT,
        timestamp TEXT,
    );

    CREATE TABLE IF NOT EXISTS shooting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target TEXT,
        system TEXT,
        timestamp TEXT,
		    success BOOLEAN,
		    result_timestamp TEXT,
    );
EOF
}


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
		spro_ammo=$(< "$spro_ammo_file")
    zrdn1_ammo=$(< "$zrdn1_ammo_file")
    zrdn2_ammo=$(< "$zrdn2_ammo_file")
    zrdn2_ammo=$(< "$zrdn2_ammo_file")


    spro_check=$(echo "$spro_ammo==0 "| bc -l)
    if [ $spro_check -eq 1 ]
    then
        echo "10" > $spro_ammo_file
        echo "`date` [SPRO] Пополнение боеприпаса" >> "$kp_logs"
    fi

    zrdn_check=$(echo "$zrdn1_ammo==0 "| bc -l)
    if [ $zrdn_check -eq 1 ]
    then
        echo "20" > $zrdn1_ammo_file
        echo "`date` [ZRDN1] Пополнение боеприпаса" >> "$kp_logs"
    fi

    zrdn2_check=$(echo "$zrdn2_ammo==0 "| bc -l)
    if [ $zrdn2_check -eq 1 ]
    then
        echo "20" > $zrdn2_ammo_file
        echo "`date` [ZRDN2] Пополнение боеприпаса" >> "$kp_logs"
    fi

    zrdn3_check=$(echo "$zrdn3_ammo==0 "| bc -l)
    if [ $zrdn3_check -eq 1 ]
    then
        echo "20" > $zrdn3_ammo_file
        echo "`date` [ZRDN3] Пополнение боеприпаса" >> "$kp_logs"
    fi

		sleep 5
	done
}


let i=0

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
      #sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO detections (id, speed, ttype, direction) VALUES ('$target_id', $speed, '$target_type', $direction);"
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
	  fi
  fi

  ps=`ps -eo args`
  ps_zrdn1=`echo $ps | grep -c "ZRDN1" | grep -v grep`
  ps_zrdn2=`echo $ps | grep -c "ZRDN2" | grep -v grep`
  ps_zrdn3=`echo $ps | grep -c "ZRDN3" | grep -v grep`
  ps_rls1=`echo $ps | grep -c "RLS1" | grep -v grep`
  ps_rls2=`echo $ps | grep -c "RLS2" | grep -v grep`
  ps_rls3=`echo $ps | grep -c "RLS3" | grep -v grep`

  if [[ $ps_zrdn1 == $bad_num_proc ]]
  then
    $file_to_run_zrdn $config_file_zrdn 'ZRDN1' $file_log_zrdn $zrdn_logs $temp_file1 &
    echo "`date` zrdn1: Работоспособность восстановлена" >> $zrdn_logs
  fi
  if [[ $ps_zrdn2 == $bad_num_proc ]]
  then
    $file_to_run_zrdn $config_file_zrdn 'ZRDN2' $file_log_zrdn $zrdn_logs $temp_file2 &
    echo "`date` zrdn2: Работоспособность восстановлена" >> $zrdn_logs
  fi
  if [[ $ps_zrdn3 == $bad_num_proc ]]
  then
    $file_to_run_zrdn $config_file_zrdn 'ZRDN3' $file_log_zrdn $zrdn_logs $temp_file3 &
    echo "`date` zrdn3: Работоспособность восстановлена" >> $zrdn_logs
  fi

  if [[ $ps_rls1 == $bad_num_proc ]]
  then
    $file_to_run_rls $config_file_rls 'RLS1' $file_log_rls $rls_logs &
    echo "`date` rls1: Работоспособность восстановлена" >> $rls_logs
  fi
  if [[ $ps_rls2 == $bad_num_proc ]]
  then
    $file_to_run_rls $config_file_rls 'RLS2' $file_log_rls $rls_logs &
    echo "`date` rls2: Работоспособность восстановлена" >> $rls_logs
  fi
  if [[ $ps_rls3 == $bad_num_proc ]]
  then
    $file_to_run_rls $config_file_rls 'RLS3' $file_log_rls $rls_logs &
    echo "`date` rls3: Работоспособность восстановлена" >> $rls_logs
  fi
done


