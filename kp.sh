#!/bin/bash

rls_messages="messages/message_rls"
spro_messages="messages/message_spro"
zrdn_messages="messages/message_zrdn"
kp_logs="logs/kp_logs"
rls_logs="logs/rls"
spro_logs="logs/spro"
zrdn_logs="logs/zrdn"

echo "" > $kp_logs
echo "" > $rls_logs
echo "" > $spro_logs
echo "" > $zrdn_logs

let i=0

while :
do
	let i=i+1

	# проверка рлс
	last_rls_data=`cat $rls_messages | tail -n 1 | awk '{print $0 $1 $2 $3 $4 $5 $6}'`
	messages=`cat $rls_messages` 

	# проверка спро

	# проверка зрдн

	sleep 0.5
done