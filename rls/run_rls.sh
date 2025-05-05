#!/bin/bash

rls1="rls1"
rls2="rls2"
rls3="rls3"

file_to_run="./rls/rls.sh"
config_file="rls/config.yaml"

file_log="temp/logs/rls_logs"
message_rls="messages/message_rls"
echo "" > $file_log
echo "" > $message_rls

bad_num_proc=0
check_systems_time=10

# завершение дочерних процессов
parent_pid=$$
cleanup() {
pkill -P $parent_pid
}
trap cleanup EXIT
wait

# запуск рлс
$file_to_run $config_file $rls1 $file_log $message_rls &
$file_to_run $config_file $rls2 $file_log $message_rls &
$file_to_run $config_file $rls3 $file_log $message_rls &

# проверка работоспособности 
while :
do
  sleep $check_systems_time

  ps=`ps -eo args`
  ps_rls1=`echo $ps | grep -c "$rls1"`
  ps_rls2=`echo $ps | grep -c "$rls2"`
  ps_rls3=`echo $ps | grep -c "$rls3"`

  if [[ $ps_rls1 == $bad_num_proc ]]
  then
    $file_to_run $config_file $rls1 $file_log $message_rls &
    echo "`date -u` rls1: Работоспособность восстановлена" >> $message_rls
  fi
  if [[ $ps_rls2 == $bad_num_proc ]]
  then
    $file_to_run $config_file $rls2 $file_log $message_rls &
    echo "`date -u` rls2: Работоспособность восстановлена" >> $message_rls
  fi
  if [[ $ps_rls3 == $bad_num_proc ]]
  then
    $file_to_run $config_file $rls3 $file_log $message_rls &
    echo "`date -u` rls3: Работоспособность восстановлена" >> $message_rls
  fi
done

