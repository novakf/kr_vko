#!/bin/bash


# Проверка, что пользователь не администратор (root)
if [ "$(id -u)" -eq 0 ]; then
    echo "Ошибка: Этот скрипт нельзя запускать с правами администратора (root)." >&2
    exit 1
fi

# Проверка операционной системы (должна быть Linux)
if [ "$(uname -s)" != "Linux" ]; then
    echo "Ошибка: Этот скрипт предназначен только для Linux." >&2
    exit 1
fi

# Проверка, что интерпретатор - Bash (может быть вызван как sh, но должен быть bash)
if [ -z "$BASH_VERSION" ]; then
    echo "Ошибка: Этот скрипт должен запускаться в интерпретаторе Bash." >&2
    exit 1
fi

echo '...Запуск всех систем...'

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