#!/bin/bash

zrdn1="ZRDN1"
zrdn2="ZRDN2"
zrdn3="ZRDN3"
FILE_TO_RUN="./zrdn/zrdn.sh"
CONFIG_FILE="zrdn/config.yaml"
DETECTED_TARGETS_FILE="tmp/detected_targets/zrdn"
MESSAGE_ZRDN="messages/message_zrdn"
LOG_ZRDN='logs/zrdn'
SHOOTED_TARGETS_ZRDN1="tmp/shooted_targets/zrdn1"
SHOOTED_TARGETS_ZRDN2="tmp/shooted_targets/zrdn2"
SHOOTED_TARGETS_ZRDN3="tmp/shooted_targets/zrdn3"
echo "" > $DETECTED_TARGETS_FILE
echo "" > $MESSAGE_ZRDN
echo "" > $SHOOTED_TARGETS_ZRDN1
echo "" > $SHOOTED_TARGETS_ZRDN2
echo "" > $SHOOTED_TARGETS_ZRDN3

# запуск зрдн
$FILE_TO_RUN $CONFIG_FILE $zrdn1 $DETECTED_TARGETS_FILE $LOG_ZRDN $SHOOTED_TARGETS_ZRDN1 $MESSAGE_ZRDN &
$FILE_TO_RUN $CONFIG_FILE $zrdn2 $DETECTED_TARGETS_FILE $LOG_ZRDN $SHOOTED_TARGETS_ZRDN2 $MESSAGE_ZRDN &
$FILE_TO_RUN $CONFIG_FILE $zrdn3 $DETECTED_TARGETS_FILE $LOG_ZRDN $SHOOTED_TARGETS_ZRDN3 $MESSAGE_ZRDN &

# завершение дочерних процессов
parentPid=$$
cleanup() {
pkill -P $parentPid
}
trap cleanup EXIT
wait
