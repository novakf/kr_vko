#!/bin/bash

config_file=$1
zrdn_num=$2
detected_targets=$3
log_zrdn=$4
shooted_targets_file=$5
message_zrdn=$6
delim=":"
ammo=20
targets_dir="/tmp/GenTargets/Targets/"
destroy_dir="/tmp/GenTargets/Destroy/"
ammo_file="zrdn/ammo_$zrdn_num"
echo $ammo > $ammo_file


if [ -f "$config_file" ]; then
	x0=$(grep -E "$zrdn_num$delim" "$config_file" -A 5 | grep 'x0:' | awk '{print $2}')
	y0=$(grep -E "$zrdn_num$delim" "$config_file" -A 5 | grep 'y0:' | awk '{print $2}')
	r=$(grep -E "$zrdn_num$delim" "$config_file" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $config_file не найден."
	exit 1
fi

sendMessage() {
	local content="$1"

	local file_path="${message_zrdn}"

	# Создаём контрольную сумму SHA-256
	local checksum=$(echo -n "$content" | sha256sum | cut -d' ' -f1)
	# Шифрование base64
	local encrypted_content=$(echo -n "$content" | base64 -w 0)

	echo "$checksum $encrypted_content" >> "messages/message_zrdn"
}

function inZrdnZone()
{
	local dx=$1
	local dy=$2
	local R=$3

	local r=$(echo "sqrt ( (($dx*$dx+$dy*$dy)) )" | bc -l)
	r=${r/\.*}

	if (( $r <= $R ))
	then
		return 1
	fi
	return 0
}


function decodeTargetId() {
	local filename=$1
	local decodedHex=""
	for ((i = 2; i <= ${#filename}; i += 4)); do
		decodedHex+="${filename:$i:2}"
	done
	echo -n "$decodedHex" | xxd -r -p
}


while :
do
	# считывание из временного файла
	shooted_targets=`cat $shooted_targets_file`
	# считывание из директория gentargets
	files=`ls $targets_dir -t 2>/dev/null | head -30`
	targets=""
  ammo=$(< "$ammo_file")

	# создание строки с id
	for file in $files
	do
    curr_id=$(decodeTargetId "$file")
		targets="$targets ${curr_id}"
	done

	# проверка, что цели из файла есть в директории gentargets
	for shooted_target in $shooted_targets
	do
		id=$(echo $shooted_target | awk -F ":" '{print $1}')
		type=$(echo $shooted_target | awk -F ":" '{print $2}')
		if [[ $targets != *"$id"* ]]
		then
			if [[ $type  == "Самолет" ]]
			then
				if [[ `cat $log_zrdn | grep $id | grep -c 'поражен'` == 0 ]]
				then
					echo "`date` [$zrdn_num] ID:$id X:$x Y:$y Самолет поражен" >> $log_zrdn
          sendMessage "`date` [$zrdn_num] ID:$id X:$x Y:$y Самолет поражен"
				fi
			else
				if [[ `cat $log_zrdn | grep $id | grep -c 'поражен'` == 0 ]]
				then
					echo "`date` [$zrdn_num] ID:$id X:$x Y:$y К.ракета поражена" >> $log_zrdn
          sendMessage "`date` [$zrdn_num] ID:$id X:$x Y:$y К.ракета поражена"
				fi
			fi
    else
      echo "`date` [$zrdn_num] ID:$shooted_target Промах" >> $log_zrdn
      sendMessage "`date` [$zrdn_num] ID:$shooted_target Промах"
		fi
	done
	echo "" > $shooted_targets_file
	
	for file in `ls $targets_dir -t 2>/dev/null | head -30`
	do
		fileContent=$(cat "$targets_dir$file")
    coords=$(echo ${fileContent//[X:|Y:]/""} | tr -s ' \t' ' ')
    x=${coords% *}
    y=${coords#* }
		id=$(decodeTargetId "$file")
		if [ -z "$id" ]
		then
			continue
		fi
		let dx=$x-$x0
		let dy=$y-$y0

		# проверка наличия цели в области зрдн
		targetInZone=0
		inZrdnZone $dx $dy $r
		targetInZone=$?

		if [[ $targetInZone -eq 1 ]]
		then
			# проверка наличия в файле этой цели
			str=$(tail -n 30 $detected_targets | grep $id | tail -n 1)
			num=$(tail -n 30 $detected_targets | grep -c $id)
			if [[ $num == 0 ]]
			then
				echo "`date` [$zrdn_num] ID:$id Обнаружена цель" >> $log_zrdn
				echo "$id $x $y zrdn: $zrdn_num" >> $detected_targets
        sendMessage "`date` [$zrdn_num] ID:$id Обнаружена цель"
			else
				x1=$(echo "$str" | awk '{print $2}')
				y1=$(echo "$str" | awk '{print $3}')
				let vx=x-x1
				let vy=y-y1

				# проверка цели для зрдн
				v=$(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l)
				rocket=$(echo "$v>=250 && $v<=1000 "| bc -l)
				plane=$(echo "$v>=50 && $v<=250 "| bc -l)
				# проверка на ракету
				if [ $rocket -eq 1 ]
				then
					# проверка на наличие противоракет
					if [[ $ammo -gt 0 ]]
					then
						let ammo=ammo-1
            echo $ammo > "$ammo_file"
						echo "$zrdn_num" > "$destroy_dir$id"
						echo "$id:К.ракета" >> $shooted_targets_file
					else
						echo "$zrdn_num: Противоракеты закончились" >> $log_zrdn
            sendMessage "$zrdn_num: Противоракеты закончились"
					fi 
				# проверка на самолет
				elif [ $plane -eq 1 ]; then
					# проверка на наличие противоракет
					if [[ $ammo -gt 0 ]]
					then
						let ammo=ammo-1
            echo $ammo > "$ammo_file"
						echo "$zrdn_num" > "$destroy_dir$id"
						echo "$id:Самолет" >> $shooted_targets_file

            echo "`date` [$zrdn_num] ID:$id Выстрел (осталось $ammo)" >> $log_zrdn
            sendMessage "`date` [$zrdn_num] ID:$id Выстрел (осталось $ammo)"

					else
						echo "$zrdn_num: Противоракеты закончились" >> $log_zrdn
            sendMessage "$zrdn_num: Противоракеты закончились"
					fi 
				fi
			fi
		fi
	done
  sleep 1
done

# завершение дочерних процессов
parent_pid=$$
cleanup() {
  pkill -P $parent_pid
}
trap cleanup EXIT
wait