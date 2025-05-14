#!/bin/bash

zrdn1="ZRDN1"
zrdn2="ZRDN2"
zrdn3="ZRDN3"
file_to_run="./zrdn/zrdn.sh"
config_file="zrdn/config.yaml"
file_log="temp/logs/zrdn_logs"
message_zrdn="messages/message_zrdn"
log_zrdn='logs/zrdn'
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

# запуск зрдн
$file_to_run $config_file $zrdn1 $file_log $log_zrdn $temp_file1 $message_zrdn &
$file_to_run $config_file $zrdn2 $file_log $log_zrdn $temp_file2 $message_zrdn &
$file_to_run $config_file $zrdn3 $file_log $log_zrdn $temp_file3 $message_zrdn &

# завершение дочерних процессов
parent_pid=$$
cleanup() {
pkill -P $parent_pid
}
trap cleanup EXIT
wait
