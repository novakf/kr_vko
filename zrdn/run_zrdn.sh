#!/bin/bash

zrdn1="ZRDN1"
zrdn2="ZRDN2"
zrdn3="ZRDN3"
file_to_run="./zrdn/zrdn.sh"
config_file="zrdn/config.yaml"
detected_targets="tmp/detected_targets/zrdn"
message_zrdn="messages/message_zrdn"
log_zrdn='logs/zrdn'
tmp_file1="tmp/shooted_targets/zrdn1"
tmp_file2="tmp/shooted_targets/zrdn2"
tmp_file3="tmp/shooted_targets/zrdn3"
echo "" > $detected_targets
echo "" > $message_zrdn
echo "" > $tmp_file1
echo "" > $tmp_file2
echo "" > $tmp_file3

bad_num_proc=0
check_systems_time=10

# запуск зрдн
$file_to_run $config_file $zrdn1 $detected_targets $log_zrdn $tmp_file1 $message_zrdn &
$file_to_run $config_file $zrdn2 $detected_targets $log_zrdn $tmp_file2 $message_zrdn &
$file_to_run $config_file $zrdn3 $detected_targets $log_zrdn $tmp_file3 $message_zrdn &

# завершение дочерних процессов
parent_pid=$$
cleanup() {
pkill -P $parent_pid
}
trap cleanup EXIT
wait
