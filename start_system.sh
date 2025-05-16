#!/bin/bash

shooted_targets="tmp/shooted_targets"
detected_targets="tmp/detected_targets_targets"
rm -rf $shooted_targets 2>/dev/null
rm -rf $detected_targets 2>/dev/null
mkdir $shooted_targets
mkdir $detected_targets

# запуск генератора целей
./GenTargets.sh &
sleep 0.5

# # запуск рлс
./rls/run_rls.sh $>/dev/null&

# запуск зрдн
./zrdn/run_zrdn.sh  $>/dev/null &

# запуск  спро
./spro/spro.sh $>/dev/null &

# запуск КП
./kp.sh $>/dev/null &


# завершение дочерних процессов
parent_pid=$$
cleanup() {
  pkill -P $parent_pid
}
trap cleanup EXIT
wait