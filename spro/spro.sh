#!/bin/bash

config_file="spro/config.yaml"
file_log="temp/logs/spro_logs"
message_spro="messages/message_spro"
targets_dir="/tmp/GenTargets/Targets/"
destroy_dir="/tmp/GenTargets/Destroy/"
temp_file="temp/temp/spro"
delim=":"
ammo=10
echo "" > $file_log
echo "" > $message_spro
echo "" > $temp_file



if [ -f "$config_file" ]; then
	x0=$(grep -E "spro$delim" "$config_file" -A 5 | grep 'x0:' | awk '{print $2}')
	y0=$(grep -E "spro$delim" "$config_file" -A 5 | grep 'y0:' | awk '{print $2}')
	r=$(grep -E "spro$delim" "$config_file" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $config_file не найден."
	exit 1
fi

function InSproZone()
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

function Speedometer()
{
	local vx=$1
	local vy=$2

	local v=$(echo "sqrt ( (($vx*$vx+$vy*$vy)) )" | bc -l)
	res=$(echo "$v>=8000 && $v<=10000 "| bc -l)
    if [ $res -eq 1 ]
    then
        return 1
    fi
    return 0
}

function decode_target_id() {
	local filename=$1
	local decoded_hex=""
	for ((i = 2; i <= ${#filename}; i += 4)); do
		decoded_hex+="${filename:$i:2}"
	done
	echo -n "$decoded_hex" | xxd -r -p
}

while :
do
	# считывание из временного файла
	temp_targets=`cat $temp_file`
	# считывание из директорияя gentargets
	files=`ls $targets_dir -t 2>/dev/null | head -30`
	targets=""

	# создание строки с id
	for file in $files
	do
    curr_id=$(decode_target_id "$file")
		targets="$targets ${curr_id}"
	done
	
	# проверка, что цели из файла есть в директории gentargets
	for temp_target in $temp_targets
	do
		if [[ $targets != *"$temp_target"* ]]
		then
			echo "`date -u` СПРО $temp_target $x $y : БР поражена" >> $message_spro
		fi
	done
	echo "" > $temp_file

	for file in $files
	do
    fileContent=$(cat "$targets_dir$file")
    coords=$(echo ${fileContent//[X:|Y:]/""} | tr -s ' \t' ' ')
    x=${coords% *}
    y=${coords#* }
		id=$(decode_target_id "$file")
		let dx=$x-$x0
		let dy=$y-$y0

		# проверка наличия цели в области спро
		targetInZone=0
		InSproZone $dx $dy $r
		targetInZone=$?
		if [[ $targetInZone -eq 1 ]]
		then
			# проверка наличия в файле этой цели
			str=$(tail -n 30 $file_log | grep $id | tail -n 1)
			num=$(tail -n 30 $file_log | grep -c $id)
			if [[ $num == 0 ]]
			then
				# echo "Обнаружена цель ID: $id" >> $message_spro
				echo "$id $x $y" >> $file_log
			else
				x1=$(echo "$str" | awk '{print $2}')
				y1=$(echo "$str" | awk '{print $3}')
				let vx=x-x1
				let vy=y-y1

				# проверка цели для спро
				Speedometer $vx $vy
				SpeedometerResult=$?
				if [[ $SpeedometerResult -eq 1 ]]
				thenconfig_file
					# проверка на наличие противоракет
					if [[ $ammo -gt 0 ]]
					then
						let ammo=ammo-1
						echo "" > "$destroy_dir$id"
						echo "$id" >> $temp_file
					else
						echo "Противоракеты закончились" >> $message_spro
					fi 
				fi
			fi
		fi
	done

	sleep 0.5
done