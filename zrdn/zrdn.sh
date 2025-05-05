#!/bin/bash

config_file=$1
zrdn_num=$2
file_log=$3
message_zrdn=$4
temp_file=$5
delim=":"
ammo=20
targets_dir="/tmp/GenTargets/Targets/"
destroy_dir="/tmp/GenTargets/Destroy/"


if [ -f "$config_file" ]; then
	x0=$(grep -E "$zrdn_num$delim" "$config_file" -A 5 | grep 'x0:' | awk '{print $2}')
	y0=$(grep -E "$zrdn_num$delim" "$config_file" -A 5 | grep 'y0:' | awk '{print $2}')
	r=$(grep -E "$zrdn_num$delim" "$config_file" -A 5 | grep 'r:' | awk '{print $2}')

else
	echo "Файл $config_file не найден."
	exit 1
fi

function InZrdnZone()
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
	# считывание из директория gentargets
	files=`ls $targets_dir -t 2>/dev/null | head -30`
	targets=""

	# создание строки с id
	for file in $files
	do
    curr_id=$(decode_target_id "$file")
		targets="$targets ${id}"
	done
	# проверка, что цели из файла есть в директории gentargets
	for temp_target in $temp_targets
	do
		id=$(echo $temp_target | awk -F ":" '{print $1}')
		type=$(echo $temp_target | awk -F ":" '{print $2}')
		if [[ $targets != *"$id"* ]]
		then
			if [[ $type  == "Самолет" ]]
			then
				if [[ `cat $message_zrdn | grep -c $id` == 0 ]]
				then
					echo "`date -u` $zrdn_num $id $x $y: Самолет поражен" >> $message_zrdn
				fi
			else
				if [[ `cat $message_zrdn | grep -c $id` == 0 ]]
				then
					echo "`date -u` $zrdn_num $id $x $y: К.ракета поражена" >> $message_zrdn
				fi
			fi
		fi
	done
	echo "" > $temp_file
	
	for file in `ls $targets_dir -t 2>/dev/null | head -30`
	do
		fileContent=$(cat "$targets_dir$file")
    coords=$(echo ${fileContent//[X:|Y:]/""} | tr -s ' \t' ' ')
    x=${coords% *}
    y=${coords#* }
		id=$(decode_target_id "$file")
		let dx=$x-$x0
		let dy=$y-$y0

		# проверка наличия цели в области зрдн
		targetInZone=0
		InZrdnZone $dx $dy $r
		targetInZone=$?

		if [[ $targetInZone -eq 1 ]]
		then
			# проверка наличия в файле этой цели
			str=$(tail -n 30 $file_log | grep $id | tail -n 1)
			num=$(tail -n 30 $file_log | grep -c $id)
			if [[ $num == 0 ]]
			then
				# echo "Обнаружена цель ID: $id" >> $message_zrdn
				echo "$id $x $y zrdn: $zrdn_num" >> $file_log
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
						echo "" > "$destroy_dir$id"
						echo "$id:К.ракета" >> $temp_file
					else
						echo "Противоракеты закончились" >> $message_zrdn
					fi 
				# проверка на самолет
				elif [ $plane -eq 1 ]; then
					# проверка на наличие противоракет
					if [[ $ammo -gt 0 ]]
					then
						let ammo=ammo-1
						echo "" > "$destroy_dir$id"
						echo "$id:Самолет" >> $temp_file
					else
						echo "$zrdn_num: Противоракеты закончились" >> $message_zrdn
					fi 
				fi
			fi
		fi
	done

	sleep 0.5
done