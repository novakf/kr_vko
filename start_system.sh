#!/bin/bash

temp_logs="temp/logs"
temp_temp="temp/temp"
rm -rf $temp_logs 2>/dev/null
rm -rf $temp_temp 2>/dev/null
mkdir $temp_logs
mkdir $temp_temp

# запуск генератора целей
./GenTargets.sh &
sleep 0.5

# # запуск рлс
./rls/run_rls.sh &

# запуск зрдн
./zrdn/run_zrdn.sh  &

# запуск  спро
./spro/spro.sh &

# запуск КП
./kp.sh &


# завершение дочерних процессов
parent_pid=$$
cleanup() {
  pkill -P $parent_pid
}
trap cleanup EXIT
wait