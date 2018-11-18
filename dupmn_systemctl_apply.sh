#!/bin/bash

function get_conf() { 
	# $1 = conf_file
	local str_map="( ";
	for line in `sed '/^$/d' $1`; do
		str_map+="[${line%=*}]=${line#*=} "
	done
	str_map+=" )"
	echo -e "$str_map"
}

function configure_systemd() {
	# $1 = prof_file | $2 = instance_number
	
	local -A prof=$(get_conf .dupmn/$1)

	local coin_name="${prof[COIN_NAME]}"
	local coin_path="${prof[COIN_PATH]}"
	local coin_daemon="${prof[COIN_DAEMON]}"
	local coin_cli="${prof[COIN_CLI]}"
	local coin_folder="${prof[COIN_FOLDER]}"
	local coin_config="${prof[COIN_CONFIG]}"

	echo -e "[Unit]\
	\nDescription=$coin_name-$2 service\
	\nAfter=network.target\
	\n\
	\n[Service]\
	\nUser=root\
	\nGroup=root\
	\n\
	\nType=forking\
	\n#PIDFile=$coin_folder$2/$coin_name.pid\
	\n\
	\nExecStart=$coin_path$coin_daemon -daemon -conf=$coin_folder$2/$coin_config -datadir=$coin_folder$2\
	\nExecStop=-$coin_path$coin_cli -conf=$coin_folder$2/$coin_config -datadir=$coin_folder$2 stop\
	\n\
	\nRestart=always\
	\nPrivateTmp=true\
	\nTimeoutStopSec=60s\
	\nTimeoutStartSec=10s\
	\nStartLimitInterval=120s\
	\nStartLimitBurst=5\
	\n\
	\n[Install]\
	\nWantedBy=multi-user.target" > /etc/systemd/system/$coin_name-$2.service
	chmod +x /etc/systemd/system/$coin_name-$2.service

	systemctl daemon-reload
	sleep 3
	systemctl start $coin_name-$2.service
	systemctl enable $coin_name-$2.service > /dev/null 2>&1

	if [[ -z "$(ps axo cmd:100 | egrep $coin_daemon-$2)" ]]; then
		echo -e "${RED}$coin_name-$2 is not running${NC}, please investigate. You should start by running the following commands as root:"
		echo -e "${GREEN}systemctl start $coin_name-$2.service"
		echo -e "systemctl status $coin_name-$2.service"
		echo -e "less /var/log/syslog${NC}"
	fi
}



rm -rf dupmn.sh
rm -rf dupmn_install.sh
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn_install.sh
bash dupmn_install.sh > /dev/null
rm -rf dupmn_install.sh

prof_filename="CARDbuyers"

if [ ! -z "$1" ]; then
	prof_filename="$1"
	if [ ! -f ".dupmn/$1" ]; then 
		echo -e "there's not a profile called $2"
		exit
	fi
fi

declare -A conf=$(get_conf .dupmn/dupmn.conf)
count=$((${conf[$prof_filename]}))

echo -e "$count duplicated mns to update..."

for (( i=1; i<=$count; i++ )); do 
	rm -rf /etc/init.d/$prof_filename-$i-init
	configure_systemd $prof_filename $i
	echo -e "Configured CARDbuyers-$i.service"
done
