#!/bin/bash

CONFIG_FILE=$1
RLS_NUM=$2
DETECTED_TARGETS_FILE=$3
LOG_RLS=$4
MESSAGE_RLS=$5
DELIM=":"
TARGETS_DIR="/tmp/GenTargets/Targets/"

if [ -f "$CONFIG_FILE" ]; then
    x0=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'x0:' | awk '{print $2}')
    y0=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'y0:' | awk '{print $2}')
    az=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'az:' | awk '{print $2}')
    ph=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'ph:' | awk '{print $2}')
    r=$(grep -E "$RLS_NUM$DELIM" "$CONFIG_FILE" -A 5 | grep 'r:' | awk '{print $2}')
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
    local dx=$1
    local dy=$2
    local R=$3
    local AZ=$4
    local PH=$5

    local r=$(echo "sqrt ( (($dx*$dx+$dy*$dy)) )" | bc -l)
    r=${r/\.*}

    if (( $r <= $R ))
    then
        local phi=$(echo | awk " { x=atan2($dy,$dx)*180/3.14; print x}")
        phi=(${phi/\,*})
        checkPhi=$(echo "$phi < 0"| bc)
        if [[ "$checkPhi" -eq 1 ]]
        then
            phi=$(echo "360 + $phi" | bc)
        fi
        let phiMax=$AZ+PH/2
        let phiMin=$AZ-PH/2

        checkPhiMax=$(echo "$phi <= $phiMax"| bc)
        checkPhiMin=$(echo "$phi >= $phiMin"| bc)
        if (( $checkPhiMax == 1 )) && (( $checkPhiMin == 1 ))
        then
            return 1
        fi
    fi
    return 0
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
    local vx=$1
    local vy=$2
    local dx=$3
    local dy=$4
    local R=$5

    # расстояние цели до спро
    local r=$(echo "sqrt ( (($dx*$dx+$dy*$dy)) )" | bc -l)
    # расстояние между засечками
    local v=$(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l)

    cos=$(echo "($vx*$dx + $vy*$dy) / ($r * $v)" | bc -l)
    b=$(echo "$r * sqrt(1 - $cos * $cos)" | bc -l)
    res=$(echo "$b <= $R && $cos > 0" | bc -l)
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

        
        # проверка наличия цели в области видимости рлс
        inRlsZone $dx $dy $r $az $ph
        targetInZone=$?

        if [[ $targetInZone -eq 1 ]]
        then
            # проверка наличия в файле этой цели
            str=$(tail -n 30 $DETECTED_TARGETS_FILE | grep $id | tail -n 1)
            num=$(tail -n 30 $DETECTED_TARGETS_FILE | grep -c $id)

            if [[ $num == 0 ]]
            then
                # echo "Обнаружена цель ID: $id" >> $LOG_RLS
                echo "$id $x $y rls: $RLS_NUM" >> $DETECTED_TARGETS_FILE

            else
                x1=$(echo "$str" | awk '{print $2}')
                y1=$(echo "$str" | awk '{print $3}')
                let vx=x-x1
                let vy=y-y1
                v=$(printf %.2f $(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l))

                # проверка, что цель - БР
                calculatedSpeed $v
                speedResult=$?
                if [[ $speedResult -eq 1 ]]
                then
                    let dx=$x0-$x1
                    let dy=$y0-$y1

                    # проверка, что цель летит в сторону спро
                    sproDirection $vx $vy $dx $dy $r
                    sproDirectionResult=$?
                    if [[ $sproDirectionResult -eq 1 ]]
                    then
                        # проверка что БР, летящая к спро обнаружена
                        check=$(cat $LOG_RLS | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date` [$RLS_NUM] ID:$id X:$x Y:$y БР движется в направлении СПРО (V=$v)" >> $LOG_RLS
                            sendMessage "`date` [$RLS_NUM] ID:$id X:$x Y:$y БР движется в направлении СПРО (V=$v)"
                        fi
                    else
                        check=$(cat $LOG_RLS | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date` [$RLS_NUM] ID:$id X:$x Y:$y Обнаружена БР (V=$v)" >> $LOG_RLS
                            sendMessage "`date` [$RLS_NUM] ID:$id X:$x Y:$y Обнаружена БР (V=$v)"
                        fi
                    fi
                fi
            fi
        fi
    done

    #sleep 0.5
done