#!/bin/bash

CONFIG_FILE=$1
RLS_NUM=$2
DETECTED_TARGETS_FILE=$3
LOG_RLS=$4
MESSAGE_RLS=$5
DELIM=":"
TARGETS_DIR="/tmp/GenTargets/Targets/"

SPRO_X="6200000" 
SPRO_Y="3750000" 
SPRO_R="1000000"

if [ -f "$CONFIG_FILE" ]; then
    x0=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'x0:' | awk '{print $2}')
    y0=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'y0:' | awk '{print $2}')
    az=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'az:' | awk '{print $2}')
    ph=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'ph:' | awk '{print $2}')
    r=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'r:' | awk '{print $2}')
    echo "$RLS_NUM $x0 $y0 $az $ph $r" >> $LOG_RLS
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

	echo "$checksum $encryptedContent" >> "$MESSAGE_RLS"
}

function inRlsZone()
{
    local targetX="$1"
    local targetY="$2"
    local rlsX="$3"
    local rlsY="$4"
    local rlsAz="$5"
    local rlsAngle="$6"
    local rlsRadius="$7"

    distanceToTarget=$(./utils/calculateDistance "$rlsX" "$rlsY" "$targetX" "$targetY")
    if (($(echo "$distanceToTarget > $rlsRadius" | bc -l))); then 
      return 0
    fi    

    isTargetInAngle=$(./utils/isInRlsDirection "$targetX" "$targetY" "$rlsX" "$rlsY" "$rlsAz" "$rlsAngle")
		if [[ "$isTargetInAngle" -eq 0 ]]; then
      return 0
    fi

    return 1
}


function calculatedSpeed()
{
    local v=$1
    res=$(echo "$v>=8000  && $v<=10000 "| bc -l)
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

i=0

while :
do
    for file in `ls $TARGETS_DIR -t 2>/dev/null | head -30`
    do
        fileContent=$(cat "$TARGETS_DIR$file")
        coords=$(echo ${fileContent//[X:|Y:]/""} | tr -s ' \t' ' ')
        x=${coords% *}
        y=${coords#* }
        id=$(decodeTargetId "$file")
        let dx=$x0-$x
        let dy=$y0-$y
        if [ -z "$id" ]
		    then
			    continue
		    fi

        input=$(stat "$TARGETS_DIR$file" | grep Birth)
        datePart=$(echo "$input" | awk '{print $2 " " $3}' | cut -d. -f1)
        millis=$(echo "$input" | awk '{print $3}' | cut -d. -f2 | cut -c1-3)
        unixTime=$(date -d "$datePart" +%s)
        fileTime=$unixTime$millis

        
        # проверка наличия цели в области видимости рлс
        inRlsZone $x $y $x0 $y0 $az $ph $r
        targetInZone=$?

        if [[ $targetInZone -eq 1 ]]
        then
            # проверка наличия в файле этой цели
            str=$(tail -n 30 $DETECTED_TARGETS_FILE | grep $id | tail -n 1)
            num=$(tail -n 30 $DETECTED_TARGETS_FILE | grep -c $id)

            str1=$(grep $id $DETECTED_TARGETS_FILE)

            if [[ $num == 0 ]]
            then
              echo
                # echo "Обнаружена цель ID: $id" >> $LOG_RLS
                echo "$id $x $y $fileTime $RLS_NUM" >> $DETECTED_TARGETS_FILE
            else
                x1=$(echo "$str" | awk '{print $2}')
                y1=$(echo "$str" | awk '{print $3}')
                time=$(echo "$str" | awk '{print $4}')
                let vx=x-x1
                let vy=y-y1
                timeDiff=$(echo "$fileTime-$time" | bc -l)
                v=$(printf %.2f $(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l))

                if (($(echo "$timeDiff > 2000" | bc -l))); then
                  d=$(printf %.3f $(echo "$timeDiff/1000" | bc -l))
                  v=$(printf %.3f $(echo "$v/$d" | bc -l))
                fi

                # проверка, что цель - БР
                calculatedSpeed $v
                speedResult=$?
                if [[ $speedResult -eq 1 ]]
                then
                    let dx=$x0-$x1
                    let dy=$y0-$y1

                    # проверка, что цель летит в сторону спро
                    ./utils/isTrajectoryIntersectingCircle "$x1" "$y1" "$x" "$y" "$SPRO_X" "$SPRO_Y" "$SPRO_R"
                    sproDirectionResult=$?
                    if [[ $sproDirectionResult -eq 1 ]]
                    then
                        # проверка что БР, летящая к спро обнаружена
                        check=$(cat $LOG_RLS | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date +"%T.%3N"` [$RLS_NUM] ID:$id X:$x Y:$y БР движется в направлении СПРО (V=$v)" >> $LOG_RLS
                            sendMessage "`date +"%T.%3N"` [$RLS_NUM] ID:$id X:$x Y:$y БР движется в направлении СПРО (V=$v)"
                        fi
                    else
                        check=$(cat $LOG_RLS | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date +"%T.%3N"` [$RLS_NUM] ID:$id X:$x Y:$y Обнаружена БР (V=$v)" >> $LOG_RLS
                            sendMessage "`date +"%T.%3N"` [$RLS_NUM] ID:$id X:$x Y:$y Обнаружена БР (V=$v)"
                        fi
                    fi
                fi
            fi
        fi
    done

    sleep 0.8
done