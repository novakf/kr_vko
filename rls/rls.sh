#!/bin/bash

config_file=$1
rls_num=$2
file_log=$3
log_rls=$4
message_rls=$5
delim=":"
targets_dir="/tmp/GenTargets/Targets/"

if [ -f "$config_file" ]; then
    x0=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'x0:' | awk '{print $2}')
    y0=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'y0:' | awk '{print $2}')
    az=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'az:' | awk '{print $2}')
    ph=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'ph:' | awk '{print $2}')
    r=$(grep -E "$rls_num$delim" "$config_file" -A 5 | grep 'r:' | awk '{print $2}')
else
    echo "Файл $config_file не найден."
    exit 1
fi

sendMessage() {
	local content="$1"
	local file_path="${message_rls}"

	# Создаём контрольную сумму SHA-256
	local checksum=$(echo -n "$content" | sha256sum | cut -d' ' -f1)
	# Шифрование base64
	local encrypted_content=$(echo -n "$content" | base64 -w 0)

	echo "$checksum $encrypted_content" >> "$file_path"
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
        check_phi=$(echo "$phi < 0"| bc)
        if [[ "$check_phi" -eq 1 ]]
        then
            phi=$(echo "360 + $phi" | bc)
        fi
        let phiMax=$AZ+PH/2
        let phiMin=$AZ-PH/2

        check_phiMax=$(echo "$phi <= $phiMax"| bc)
        check_phiMin=$(echo "$phi >= $phiMin"| bc)
        if (( $check_phiMax == 1 )) && (( $check_phiMin == 1 ))
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
	local decoded_hex=""
	for ((i = 2; i <= ${#filename}; i += 4)); do
		decoded_hex+="${filename:$i:2}"
	done
	echo -n "$decoded_hex" | xxd -r -p
}

while :
do
    for file in `ls $targets_dir -t 2>/dev/null | head -30`
    do
        fileContent=$(cat "$targets_dir$file")
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
            str=$(tail -n 30 $file_log | grep $id | tail -n 1)
            num=$(tail -n 30 $file_log | grep -c $id)

            if [[ $num == 0 ]]
            then
                # echo "Обнаружена цель ID: $id" >> $log_rls
                echo "$id $x $y rls: $rls_num" >> $file_log

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
                        check=$(cat $log_rls | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date` [$rls_num] ID:$id X:$x Y:$y БР движется в направлении СПРО (V=$v)" >> $log_rls
                            sendMessage "`date` [$rls_num] ID:$id X:$x Y:$y БР движется в направлении СПРО (V=$v)"
                        fi
                    else
                        check=$(cat $log_rls | grep "$id")
                        if [ -z "$check" ]
                        then
                            echo "`date` [$rls_num] ID:$id X:$x Y:$y Обнаружена БР (V=$v)" >> $log_rls
                            sendMessage "`date` [$rls_num] ID:$id X:$x Y:$y Обнаружена БР (V=$v)"
                        fi
                    fi
                fi
            fi
        fi
    done

    #sleep 0.5
done