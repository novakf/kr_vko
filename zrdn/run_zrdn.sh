#!/bin/bash

zrdn1="zrdn1"
zrdn2="zrdn2"
zrdn3="zrdn3"
file_to_run="./zrdn/zrdn.sh"
config_file="zrdn/config.yaml"
file_log="temp/logs/zrdn_logs"
message_zrdn="messages/message_zrdn"
temp_file1="temp/temp/zrdn1"
temp_file2="temp/temp/zrdn2"
temp_file3="temp/temp/zrdn3"
echo "" > $file_log
echo "" > $message_zrdn
echo "" > $temp_file1
echo "" > $temp_file2
echo "" > $temp_file3

bad_num_proc=0
check_systems_time=10

# завершение дочерних процессов
parent_pid=$$
cleanup() {
pkill -P $parent_pid
}
trap cleanup EXIT
wait

# запуск зрдн
$file_to_run $config_file $zrdn1 $file_log $message_zrdn $temp_file1 &
$file_to_run $config_file $zrdn2 $file_log $message_zrdn $temp_file2 &
$file_to_run $config_file $zrdn3 $file_log $message_zrdn $temp_file3 &


# проверка работоспособности 
while :
do
  sleep $check_systems_time

  ps=`ps -eo args`
  ps_zrdn1=`echo $ps | grep -c "$zrdn1"`
  ps_zrdn2=`echo $ps | grep -c "$zrdn2"`
  ps_zrdn3=`echo $ps | grep -c "$zrdn3"`

  if [[ $ps_zrdn1 == $bad_num_proc ]]
  then
    $file_to_run $config_file $zrdn1 $file_log $message_zrdn $temp_file1 &
    echo "`date -u` zrdn1: Работоспособность восстановлена" >> $message_zrdn
  fi
  if [[ $ps_zrdn2 == $bad_num_proc ]]
  then
    $file_to_run $config_file $zrdn2 $file_log $message_zrdn $temp_file2 &
    echo "`date -u` zrdn2: Работоспособность восстановлена" >> $message_zrdn
  fi
  if [[ $ps_zrdn3 == $bad_num_proc ]]
  then
    $file_to_run $config_file $zrdn3 $file_log $message_zrdn $temp_file3 &
    echo "`date -u` zrdn3: Работоспособность восстановлена" >> $message_zrdn
  fi
done
