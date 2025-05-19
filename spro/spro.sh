#!/bin/bash

CONFIG_FILE="spro/config.yaml"
DETECTED_TARGETS_FILE="tmp/detected_targets/spro"
MESSAGE_SPRO="messages/message_spro"
LOG_SPRO="logs/spro"
TARGETS_DIR="/tmp/GenTargets/Targets/"
DESTROY_DIR="/tmp/GenTargets/Destroy/"
SHOOTED_TARGETS_FILE="tmp/shooted_targets/spro"
AMMO_FILE="spro/ammo"
DELIM=":"
ammo=10
echo "" > $DETECTED_TARGETS_FILE
echo "" > $MESSAGE_SPRO
echo "" > $LOG_SPRO
echo "" > $SHOOTED_TARGETS_FILE
echo "$ammo" > $AMMO_FILE


if [ -f "$CONFIG_FILE" ]; then
	x0=$(grep -E "SPRO$DELIM" "$CONFIG_FILE" -A 5 | grep 'x0:' | awk '{print $2}')
	y0=$(grep -E "SPRO$DELIM" "$CONFIG_FILE" -A 5 | grep 'y0:' | awk '{print $2}')
	sproR=$(grep -E "SPRO$DELIM" "$CONFIG_FILE" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $CONFIG_FILE не найден."
	exit 1
fi

function inSproZone()
{
	local x=$1
	local y=$2

  distanceToTarget=$(./utils/calculateDistance "$x0" "$y0" "$x" "$y")
	if (($(echo "$distanceToTarget <= $sproR" | bc -l))); then
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

  if [ $time -gt 2000 ]
  then
      local v=$(echo "$s/($time/1000)" | bc -l)
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

	echo "$checksum $encryptedContent" >> "$MESSAGE_SPRO"
}

while :
do
	# считывание из временного файла
	shootedTargets=`cat $SHOOTED_TARGETS_FILE`
	# считывание из директорияя gentargets
	files=`ls $TARGETS_DIR -t 2>/dev/null | head -30`
	targets=""
  ammo=$(< "$AMMO_FILE")

	# создание строки с id
	for file in $files
	do
    currId=$(decodeTargetId "$file")
		targets="$targets ${currId}"
	done
	
	# проверка, что цели из файла есть в директории gentargets
	for shootedTarget in $shootedTargets
	do
		if [[ $targets != *"$shootedTarget"* ]]
		then
			echo "`date +"%T.%3N"` [SPRO] ID:$shootedTarget X:$x Y:$y БР поражена" >> $LOG_SPRO
      sendMessage "`date +"%T.%3N"` [SPRO] ID:$shootedTarget X:$x Y:$y БР поражена"
    else
      echo "`date +"%T.%3N"` [SPRO] ID:$shootedTarget X:$x Y:$y Промах" >> $LOG_SPRO
      sendMessage "`date +"%T.%3N"` [SPRO] ID:$shootedTarget X:$x Y:$y Промах"
		fi
	done
	echo "" > $SHOOTED_TARGETS_FILE

	for file in $files
	do
    fileContent=$(cat "$TARGETS_DIR$file")

    input=$(stat "$TARGETS_DIR$file" | grep Birth)
    datePart=$(echo "$input" | awk '{print $2 " " $3}' | cut -d. -f1)
    millis=$(echo "$input" | awk '{print $3}' | cut -d. -f2 | cut -c1-3)
    unixTime=$(date -d "$datePart" +%s)
    fileTime=$unixTime$millis

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
		inSproZone $x $y
		targetInZone=$?
		if [[ $targetInZone -eq 1 ]]
		then
			# проверка наличия в файле этой цели
			str=$(grep $id $DETECTED_TARGETS_FILE)

			if [ -z "$str" ]
			then
				echo "`date +"%T.%3N"` [SPRO] ID:$id Обнаружена цель" >> $LOG_SPRO
        sendMessage "`date +"%T.%3N"` [SPRO] ID:$id Обнаружена цель"
				echo "$id $x $y $fileTime" >> $DETECTED_TARGETS_FILE
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
            echo $ammo > "$AMMO_FILE"
						echo "(SPRO) V:$v1" > "$DESTROY_DIR$id"
            
            echo "`date +"%T.%3N"` [SPRO] ID:$id Выстрел (осталось $ammo)" >> $LOG_SPRO
            sendMessage "`date +"%T.%3N"` [SPRO] ID:$id Выстрел (осталось $ammo)"
						
            echo "$id" >> $SHOOTED_TARGETS_FILE
					else
						echo "`date +"%T.%3N"` [SPRO] Противоракеты закончились" >> $LOG_SPRO
            sendMessage "`date +"%T.%3N"` [SPRO] Противоракеты закончились"
					fi 
				fi
			fi
		fi
	done
  sleep 1
done