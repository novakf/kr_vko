#!/bin/bash

rls1="RLS1"
rls2="RLS2"
rls3="RLS3"

FILE_TO_RUN="./rls/rls.sh"
CONFIG_FILE="rls/config.yaml"

DETECTED_TARGETS_FILE="tmp/detected_targets/rls"
MESSAGE_RLS="messages/message_rls"
LOG_FILE="logs/rls"
echo "" > $LOG_FILE
echo "" > $DETECTED_TARGETS_FILE
echo "" > $MESSAGE_RLS

# запуск рлс
$FILE_TO_RUN $CONFIG_FILE $rls1 $DETECTED_TARGETS_FILE $LOG_FILE $MESSAGE_RLS &
$FILE_TO_RUN $CONFIG_FILE $rls2 $DETECTED_TARGETS_FILE $LOG_FILE $MESSAGE_RLS &
$FILE_TO_RUN $CONFIG_FILE $rls3 $DETECTED_TARGETS_FILE $LOG_FILE $MESSAGE_RLS &

# завершение дочерних процессов
parentPid=$$
cleanup() {
pkill -P $parentPid
}
trap cleanup EXIT
wait

