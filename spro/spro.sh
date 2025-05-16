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
	r=$(grep -E "SPRO$DELIM" "$CONFIG_FILE" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $CONFIG_FILE не найден."
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
			echo "`date` [SPRO] ID:$shootedTarget X:$x Y:$y БР поражена" >> $LOG_SPRO
      sendMessage "`date` [SPRO] ID:$shootedTarget X:$x Y:$y БР поражена"
    else
      echo "`date` [SPRO] ID:$shootedTarget X:$x Y:$y Промах" >> $LOG_SPRO
      sendMessage "`date` [SPRO] ID:$shootedTarget X:$x Y:$y Промах"
		fi
	done
	echo "" > $SHOOTED_TARGETS_FILE

	for file in $files
	do
    fileContent=$(cat "$TARGETS_DIR$file")
    fileTime=$(stat -c '%Y' "$TARGETS_DIR$file")
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
			str=$(tail -n 30 $DETECTED_TARGETS_FILE | grep $id | tail -n 1)
			num=$(tail -n 30 $DETECTED_TARGETS_FILE | grep -c $id)
			if [[ $num == 0 ]]
			then
				echo "`date` [SPRO] ID:$id Обнаружена цель" >> $LOG_SPRO
        sendMessage "`date` [SPRO] ID:$id Обнаружена цель"
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
						echo "(SPRO) V:$v1 T:$timeDiff" > "$DESTROY_DIR$id"
            
            echo "`date` [SPRO] ID:$id Выстрел (осталось $ammo)" >> $LOG_SPRO
            sendMessage "`date` [SPRO] ID:$id Выстрел (осталось $ammo)"
						
            echo "$id" >> $SHOOTED_TARGETS_FILE
					else
						echo "`date` [SPRO] Противоракеты закончились" >> $LOG_SPRO
            sendMessage "`date` [SPRO] Противоракеты закончились"
					fi 
				fi
			fi
		fi
	done

  sleep 1
done