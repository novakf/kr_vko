#!/bin/bash

SHOOTED_TARGETS_DIR="tmp/shooted_targets"
DETECTED_TARGETS_DIR="tmp/detected_targets"
rm -rf $SHOOTED_TARGETS_DIR 2>/dev/null
rm -rf $DETECTED_TARGETS_DIR 2>/dev/null
mkdir $SHOOTED_TARGETS_DIR
mkdir $DETECTED_TARGETS_DIR

# запуск генератора целей
./GenTargets.sh &
sleep 0.5

# # запуск рлс
./rls/start_rls.sh $>/dev/null&

# запуск зрдн
./zrdn/start_zrdn.sh  $>/dev/null &

# запуск  спро
./spro/spro.sh $>/dev/null &

# запуск КП
./kp.sh $>/dev/null &


# завершение дочерних процессов
parentPid=$$
cleanup() {
  pkill -P $parentPid
}
trap cleanup EXIT
wait