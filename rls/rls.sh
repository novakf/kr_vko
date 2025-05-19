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

arctangens() {
    local target_x="$1"
    local target_y="$2"
    local rls_x="$3"
    local rls_y="$4"

    angle=0
    if [[ $(echo "$target_x == $rls_x" | bc) == 1 ]]; then
        if [[ $(echo "$target_y >= $rls_y" | bc) == 1 ]]; then
            angle=90
        else
            angle=270
        fi
    else
        #angle=$(echo "scale=4; a(($target_y - $rls_y)/($target_x - $rls_x))*180/3.1415927" | bc -l)
        #angle=$(echo "scale=4; if($angle < 0) $angle+360 else $angle" | bc -l)
        angle=0
    fi

    echo "$angle"
}

distance() {
	./utils/distance "$1" "$2" "$3" "$4"
}

# Функция вычисления попадания между лучами (используем bc)
beam() {
	./utils/beam "$1" "$2" "$RLS_X" "$RLS_Y" "$RLS_ALPHA" "$RLS_ANGLE"
}

check_trajectory_intersection() {
	./utils/check_trajectory_intersection "$1" "$2" "$3" "$4" "6200000" "3750000" "1000000"
}

function inRlsZone()
{
    local target_x="$1"
    local target_y="$2"
    local rls_x="$3"
    local rls_y="$4"
    local rls_azimuth="$5"
    local rls_view_angle="$6"
    local rls_radius="$7"

    dist_to_target=$(./utils/distance "$rls_x" "$rls_y" "$target_x" "$target_y")
    if (($(echo "$dist_to_target > $rls_radius" | bc -l))); then 
      return 0
    fi    

    target_in_angle=$(./utils/beam "$target_x" "$target_y" "$rls_x" "$rls_y" "$rls_azimuth" "$rls_view_angle")
		if [[ "$target_in_angle" -eq 0 ]]; then
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

function sproDirection()
{
    local target_x_1="$1"
    local target_y_1="$2"
    local target_x_2="$3"
    local target_y_2="$4"
    local spro_x="$5"
    local spro_y="$6"
    local spro_radius="$7"

    if [[ $(./utils/check_trajectory_intersection "$target_x_1" "$target_y_1" "$target_x_2" "$target_y_2" "$spro_x" "$spro_y" "$spro_radius") -eq 0 ]]; then
      return 0
    fi

    return 1
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
        date_part=$(echo "$input" | awk '{print $2 " " $3}' | cut -d. -f1)
        millis=$(echo "$input" | awk '{print $3}' | cut -d. -f2 | cut -c1-3)
        unix_time=$(date -d "$date_part" +%s)
        fileTime=$unix_time$millis

        
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
                    sproDirection "$x1" "$y1" "$x" "$y" "6200000" "3750000" "1000000"
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