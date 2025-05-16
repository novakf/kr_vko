#!/bin/bash

CONFIG_FILE=$1
ZRDN_NUM=$2
DETECTED_TARGETS=$3
LOG_ZRDN=$4
SHOOTED_TARGETS_FILE=$5
MESSAGE_ZRDN=$6
DELIM=":"
ammo=20
TARGETS_DIR="/tmp/GenTargets/Targets/"
DESTROY_DIR="/tmp/GenTargets/Destroy/"
AMMO_FILE="zrdn/ammo_$ZRDN_NUM"
echo $ammo > $AMMO_FILE


if [ -f "$CONFIG_FILE" ]; then
	x0=$(grep -E "$ZRDN_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'x0:' | awk '{print $2}')
	y0=$(grep -E "$ZRDN_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'y0:' | awk '{print $2}')
	r=$(grep -E "$ZRDN_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $CONFIG_FILE не найден."
	exit 1
fi

sendMessage() {
	local content="$1"

	# Создаём контрольную сумму SHA-256
	local checksum=$(echo -n "$content" | sha256sum | cut -d' ' -f1)
	# Шифрование base64
	local encryptedContent=$(echo -n "$content" | base64 -w 0)

	echo "$checksum $encryptedContent" >> "messages/message_zrdn"
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
	shootedTargets=`cat $SHOOTED_TARGETS_FILE`
	# считывание из директория gentargets
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
		id=$(echo $shootedTarget | awk -F ":" '{print $1}')
		type=$(echo $shootedTarget | awk -F ":" '{print $2}')
		if [[ $targets != *"$id"* ]]
		then
			if [[ $type  == "Самолет" ]]
			then
				if [[ `cat $LOG_ZRDN | grep $id | grep -c 'поражен'` == 0 ]]
				then
					echo "`date` [$ZRDN_NUM] ID:$id X:$x Y:$y Самолет поражен" >> $LOG_ZRDN
          sendMessage "`date` [$ZRDN_NUM] ID:$id X:$x Y:$y Самолет поражен"
				fi
			else
				if [[ `cat $LOG_ZRDN | grep $id | grep -c 'поражен'` == 0 ]]
				then
					echo "`date` [$ZRDN_NUM] ID:$id X:$x Y:$y К.ракета поражена" >> $LOG_ZRDN
          sendMessage "`date` [$ZRDN_NUM] ID:$id X:$x Y:$y К.ракета поражена"
				fi
			fi
    else
      echo "`date` [$ZRDN_NUM] ID:$shootedTarget Промах" >> $LOG_ZRDN
      sendMessage "`date` [$ZRDN_NUM] ID:$shootedTarget Промах"
		fi
	done
	echo "" > $SHOOTED_TARGETS_FILE
	
	for file in `ls $TARGETS_DIR -t 2>/dev/null | head -30`
	do
		fileContent=$(cat "$TARGETS_DIR$file")
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
			str=$(tail -n 30 $DETECTED_TARGETS | grep $id | tail -n 1)
			num=$(tail -n 30 $DETECTED_TARGETS | grep -c $id)
			if [[ $num == 0 ]]
			then
				echo "`date` [$ZRDN_NUM] ID:$id Обнаружена цель" >> $LOG_ZRDN
				echo "$id $x $y zrdn: $ZRDN_NUM" >> $DETECTED_TARGETS
        sendMessage "`date` [$ZRDN_NUM] ID:$id Обнаружена цель"
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
            echo $ammo > "$AMMO_FILE"
						echo "$ZRDN_NUM" > "$DESTROY_DIR$id"
						echo "$id:К.ракета" >> $SHOOTED_TARGETS_FILE
					else
						echo "$ZRDN_NUM: Противоракеты закончились" >> $LOG_ZRDN
            sendMessage "$ZRDN_NUM: Противоракеты закончились"
					fi 
				# проверка на самолет
				elif [ $plane -eq 1 ]; then
					# проверка на наличие противоракет
					if [[ $ammo -gt 0 ]]
					then
						let ammo=ammo-1
            echo $ammo > "$AMMO_FILE"
						echo "$ZRDN_NUM" > "$DESTROY_DIR$id"
						echo "$id:Самолет" >> $SHOOTED_TARGETS_FILE

            echo "`date` [$ZRDN_NUM] ID:$id Выстрел (осталось $ammo)" >> $LOG_ZRDN
            sendMessage "`date` [$ZRDN_NUM] ID:$id Выстрел (осталось $ammo)"

					else
						echo "$ZRDN_NUM: Противоракеты закончились" >> $LOG_ZRDN
            sendMessage "$ZRDN_NUM: Противоракеты закончились"
					fi 
				fi
			fi
		fi
	done
  sleep 1
done

# завершение дочерних процессов
parentPid=$$
cleanup() {
  pkill -P $parentPid
}
trap cleanup EXIT
wait