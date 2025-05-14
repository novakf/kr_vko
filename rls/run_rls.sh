#!/bin/bash

rls1="RLS1"
rls2="RLS2"
rls3="RLS3"

file_to_run="./rls/rls.sh"
config_file="rls/config.yaml"

file_log="temp/logs/rls_logs"
message_rls="messages/message_rls"
log_file="logs/rls"
echo "" > $log_file
echo "" > $file_log
echo "" > $message_rls

bad_num_proc=0
check_systems_time=10

# запуск рлс
$file_to_run $config_file $rls1 $file_log $log_file $message_rls &
$file_to_run $config_file $rls2 $file_log $log_file $message_rls &
$file_to_run $config_file $rls3 $file_log $log_file $message_rls &

# завершение дочерних процессов
parent_pid=$$
cleanup() {
pkill -P $parent_pid
}
trap cleanup EXIT
wait

