#!/bin/bash

config_file="spro/config.yaml"
detected_targets="tmp/detected_targets/spro"
message_spro="messages/message_spro"
log_spro="logs/spro"
targets_dir="/tmp/GenTargets/Targets/"
destroy_dir="/tmp/GenTargets/Destroy/"
shooted_targets_file="tmp/shooted_targets/spro"
ammo_file="spro/ammo"
delim=":"
ammo=10
echo "" > $detected_targets
echo "" > $message_spro
echo "" > $log_spro
echo "" > $shooted_targets_file
echo "$ammo" > $ammo_file


if [ -f "$config_file" ]; then
	x0=$(grep -E "SPRO$delim" "$config_file" -A 5 | grep 'x0:' | awk '{print $2}')
	y0=$(grep -E "SPRO$delim" "$config_file" -A 5 | grep 'y0:' | awk '{print $2}')
	r=$(grep -E "SPRO$delim" "$config_file" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $config_file не найден."
	exit 1
fi

function inSproZone()
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

function calculatedSpeed()
{
	local vx=$1
	local vy=$2
  local time=$3

	local s=$(echo "scale=0; sqrt($vx * $vx + $vy * $vy)" | bc -l)

  if [ $time -gt 2 ]
  then
      local v=$(echo "$s/$time" | bc -l)
  else
      local v=$(echo "$s" | bc -l)
  fi

	res=$(echo "$v>=8000 && $v<=10000 "| bc -l)
    if [ $res -eq 1 ]
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

sendMessage() {
	local content="$1"

	# Создаём контрольную сумму SHA-256
	local checksum=$(echo -n "$content" | sha256sum | cut -d' ' -f1)
	# Шифрование base64
	local encryptedContent=$(echo -n "$content" | base64 -w 0)

	echo "$checksum $encryptedContent" >> "$message_spro"
}

while :
do
	# считывание из временного файла
	shooted_targets=`cat $shooted_targets_file`
	# считывание из директорияя gentargets
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
		if [[ $targets != *"$shooted_target"* ]]
		then
			echo "`date` [SPRO] ID:$shooted_target X:$x Y:$y БР поражена" >> $log_spro
      sendMessage "`date` [SPRO] ID:$shooted_target X:$x Y:$y БР поражена"
    else
      echo "`date` [SPRO] ID:$shooted_target X:$x Y:$y Промах" >> $log_spro
      sendMessage "`date` [SPRO] ID:$shooted_target X:$x Y:$y Промах"
		fi
	done
	echo "" > $shooted_targets_file

	for file in $files
	do
    fileContent=$(cat "$targets_dir$file")
    fileTime=$(stat -c '%Y' "$targets_dir$file")
    coords=$(echo ${fileContent//[X:|Y:]/""} | tr -s ' \t' ' ')
    x=${coords% *}
    y=${coords#* }
		id=$(decodeTargetId "$file")
		let dx=$x-$x0
		let dy=$y-$y0
		if [ -z "$id" ]
		then
			continue
		fi

		# проверка наличия цели в области спро
		targetInZone=0
		inSproZone $dx $dy $r
		targetInZone=$?
		if [[ $targetInZone -eq 1 ]]
		then
			# проверка наличия в файле этой цели
			str=$(tail -n 30 $detected_targets | grep $id | tail -n 1)
			num=$(tail -n 30 $detected_targets | grep -c $id)
			if [[ $num == 0 ]]
			then
				echo "`date` [SPRO] ID:$id Обнаружена цель" >> $log_spro
        sendMessage "`date` [SPRO] ID:$id Обнаружена цель"
				echo "$id $x $y $fileTime" >> $detected_targets
			else
				x1=$(echo "$str" | awk '{print $2}')
				y1=$(echo "$str" | awk '{print $3}')
        time=$(echo "$str" | awk '{print $4}')
				let vx=x-x1
				let vy=y-y1
        timeDiff=$(echo "$fileTime-$time" | bc -l)

        v1=$(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l)

				# проверка цели для спро
				calculatedSpeed $vx $vy $timeDiff
				speedResult=$?
				if [[ $speedResult -eq 1 ]]
				then
					# проверка на наличие противоракет
					if [[ $ammo -gt 0 ]]
					then
						let ammo=ammo-1
            echo $ammo > "$ammo_file"
						echo "(SPRO) V:$v1 T:$timeDiff" > "$destroy_dir$id"
            
            echo "`date` [SPRO] ID:$id Выстрел (осталось $ammo)" >> $log_spro
            sendMessage "`date` [SPRO] ID:$id Выстрел (осталось $ammo)"
						
            echo "$id" >> $shooted_targets_file
					else
						echo "`date` [SPRO] Противоракеты закончились" >> $log_spro
            sendMessage "`date` [SPRO] Противоракеты закончились"
					fi 
				fi
			fi
		fi
	done

  sleep 1
done