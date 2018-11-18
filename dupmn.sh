#!/bin/bash

# TODO:
#  - Run dups as a service !!!
#  - Find a way to keep the consistency without moving the instance numbers on a uninstall (?)
#  - Add a command to swap instances numbers (?)
#  - Add commands to manage a swapfile (?)


# Copied from CARDbuyers mn installer script, need to adapt it for the duplicates
function configure_systemd() {

	#cat << EOF > /etc/systemd/system/$COIN_NAME.service

	[Unit]
	Description=$COIN_NAME service
	After=network.target

	[Service]
	User=root
	Group=root

	Type=forking
	#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid

	ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
	ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

	Restart=always
	PrivateTmp=true
	TimeoutStopSec=60s
	TimeoutStartSec=10s
	StartLimitInterval=120s
	StartLimitBurst=5

	[Install]
	WantedBy=multi-user.target
	#EOF

	systemctl daemon-reload
	sleep 3
	systemctl start $COIN_NAME.service
	systemctl enable $COIN_NAME.service >/dev/null 2>&1

	if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
		echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
		echo -e "${GREEN}systemctl start $COIN_NAME.service"
		echo -e "systemctl status $COIN_NAME.service"
		echo -e "less /var/log/syslog${NC}"
		exit 1
	fi
}


CYAN='\033[1;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function get_conf() { 
	# $1 = conf_file
	local str_map="( ";
	for line in `sed '/^$/d' $1`; do
		str_map+="[${line%=*}]=${line#*=} "
	done
	str_map+=" )"
	echo -e "$str_map"
}

function port_check() { 
	# $1 = port_number
	if [ ! $(lsof -Pi :$1 -sTCP:LISTEN -t) ]; then
		echo -e 1
	fi
}

function find_port() {
	# $1 = initial_check
	for (( i=$1; i<=49151; i++ )); do
		if [ $(port_check $i) ]; then
			echo -e "$i"
			return
		fi
	done
	for (( i=1024; i<$1; i++ )); do
		if [ $(port_check $i) ]; then
			echo -e "$i"
			return
		fi
	done
}

function is_number() {
	# $1 = number
	if [[ $1 =~ ^[0-9]+$ ]]; then 
		echo -e 1
	fi
}

function cmd_profadd() { 
	# $1 = profile_file | $2 = profile_name

	local -A prof=$(get_conf $1)
	local CMD_ARRAY=(COIN_NAME COIN_PATH COIN_DAEMON COIN_CLI COIN_FOLDER COIN_CONFIG)
	for var in "${CMD_ARRAY[@]}"; do
		if [[ ! "${!prof[@]}" =~ "$var" ]]; then
			echo -e "$var doesn't exists in the supplied profile file"
			exit
		elif [[ -z "${prof[$var]}" ]]; then
			echo -e "$var doesn't contain a value in the supplied profile file"
			exit
		fi
	done

	if [ ! -d ".dupmn" ]; then 
		mkdir ".dupmn"
	fi
	if [ ! -f ".dupmn/dupmn.conf" ]; then
		touch ".dupmn/dupmn.conf"
	fi
	if [ ! $(grep $2 .dupmn/dupmn.conf) ]; then
		echo -e "$2=0" >> ".dupmn/dupmn.conf"
	fi

	cp "$1" ".dupmn/$2"

	echo -e "$2 profile successfully added, use ${GREEN}dupmn install $2${NC} to create a new instance of the masternode"
}

function cmd_profdel() {
	# $1 = profile_name

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	local -A prof=$(get_conf .dupmn/$1)

	local count=$((${conf[$1]}))
	local coin_daemon=${prof[COIN_DAEMON]}
	local coin_cli=${prof[COIN_CLI]}

	if [ $(($count)) -gt $((0)) ]; then
		cmd_uninstall $1 all
	fi
	sed -i "/$1\=/d" ".dupmn/dupmn.conf"

	rm -rf /usr/bin/$coin_daemon-0
	rm -rf /usr/bin/$coin_daemon-all
	rm -rf /usr/bin/$coin_cli-0
	rm -rf /usr/bin/$coin_cli-all
	rm -rf .dupmn/$1
}

function cmd_install() {
	# $1 = profile_name

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	local -A prof=$(get_conf .dupmn/$1)
	
	local count=$((${conf[$1]}+1))
	local coin_name=${prof[COIN_NAME]}
	local coin_path=${prof[COIN_PATH]}
	local coin_daemon=${prof[COIN_DAEMON]}
	local coin_cli=${prof[COIN_CLI]}
	local coin_folder=${prof[COIN_FOLDER]}
	local coin_config=${prof[COIN_CONFIG]}

	if [ ! -d "$coin_folder" ]; then
		echo -e "$coin_folder folder can't be found, $coin_name is not installed in the system or the given profile has a wrong parameter"
		exit
	elif [ ! "$(command -v $coin_daemon)" ]; then
		echo -e "$coin_daemon command can't be found, $coin_name is not installed in the system or the given profile has a wrong parameter"
		exit
	elif [ ! "$(command -v $coin_cli)" ]; then
		echo -e "$coin_cli command can't be found, $coin_name is not installed in the system or the given profile has a wrong parameter"
		exit
	fi

	local new_key=$($coin_cli masternode genkey)
	local new_rpc=$(find_port $(($(grep -Po '(?<=rpcport=).*' $coin_folder/$coin_config)+1)))
	local new_folder="$coin_folder$count"

	mkdir $new_folder
	cp $coin_folder/$coin_config $new_folder

	sed -i "/^rpcport=/s/=.*/=$new_rpc/" $new_folder/$coin_config
	sed -i "/^listen=/s/=.*/=0/" $new_folder/$coin_config
	sed -i "/^masternodeprivkey=/s/=.*/=$new_key/" $new_folder/$coin_config

	echo -e "#!/bin/bash\n$coin_cli \$@" > /usr/bin/$coin_cli-0
	echo -e "#!/bin/bash\n$coin_daemon \$@" > /usr/bin/$coin_daemon-0
	echo -e "#!/bin/bash\n$coin_cli -datadir=$new_folder \$@" > /usr/bin/$coin_cli-$count
	echo -e "#!/bin/bash\n$coin_daemon -datadir=$new_folder \$@" > /usr/bin/$coin_daemon-$count
	echo -e "#!/bin/bash\nfor (( i=0; i<=$count; i++ )) do\n echo -e MN\$i:\n $coin_cli-\$i \$@\ndone" > /usr/bin/$coin_cli-all
	echo -e "#!/bin/bash\nfor (( i=0; i<=$count; i++ )) do\n echo -e MN\$i:\n $coin_daemon-\$i \$@\ndone" > /usr/bin/$coin_daemon-all
	chmod +x /usr/bin/$coin_cli-0
	chmod +x /usr/bin/$coin_daemon-0
	chmod +x /usr/bin/$coin_cli-$count
	chmod +x /usr/bin/$coin_daemon-$count
	chmod +x /usr/bin/$coin_cli-all
	chmod +x /usr/bin/$coin_daemon-all

	$coin_daemon -datadir=$new_folder -daemon > /dev/null

	#change for systemd
	echo -e "#!/bin/bash" \
	"\n""### BEGIN INIT INFO" \
	"\n""# Provides:          $1-$count-init" \
	"\n""# Required-Start:    \$syslog" \
	"\n""# Required-Stop:     \$syslog" \
	"\n""# Default-Start:     2 3 4 5" \
	"\n""# Default-Stop:      0 1 6" \
	"\n""# Short-Description: $1-$count-init" \
	"\n""# Description:" \
	"\n""#" \
	"\n""### END INIT INFO" \
	"\n""$coin_path$coin_daemon -datadir=$coin_folder$count -daemon" > /etc/init.d/$1-$count-init
	chmod +x /etc/init.d/$1-$count-init
	update-rc.d $1-$count-init defaults

	sed -i "/^$1=/s/=.*/=$count/" .dupmn/dupmn.conf

	echo -e "===================================================================================================\n" \
			"$coin_name duplicated masternode ${CYAN}number $count${NC} is up and syncing with the blockchain.\n" \
			"The duplicated masternode uses the same IP and port than the original one, but the private key is different and obviously it requires a different transaction (you cannot have 2 masternodes with the same transaction).\n" \
			"New RPC port is ${CYAN}$new_rpc${NC} (other programs may not be able to use this port, but you can change it with ${RED}dupmn rpcswap $1 $count PORT_NUMBER${NC})\n" \
			"Start: ${RED}$coin_daemon-$count -daemon${NC}\n" \
			"Stop:  ${RED}$coin_cli-$count stop${NC}\n" \
			"DUPLICATED MASTERNODE PRIVATEKEY is: ${GREEN}$new_key${NC}\n" \
			"Wait until the duplicated masternode is synced with the blockchain before trying to start it.\n" \
			"For check masternode status just use: ${GREEN}$coin_cli-$count masternode status${NC} (if says \"Hot Node\" => synced).\n" \
			"Note: ${GREEN}$coin_cli-0${NC} and ${GREEN}$coin_daemon-0${NC} are just a reference to the 'main masternode', not a duplicated one.\n" \
			"Note 2: You can use ${GREEN}$coin_cli-all [parameters]${NC} and ${GREEN}$coin_daemon-all [parameters]${NC} to apply the parameters on all masternodes. Example: ${GREEN}$coin_cli-all masternode status${NC}\n" \
			"==================================================================================================="
}

function cmd_list() {
	local -A conf=$(get_conf .dupmn/dupmn.conf)
	if [ ${#conf[@]} -eq 0 ]; then 
		echo -e "(no profiles added)"
	else
		for var in "${!conf[@]}"; do
			echo -e "$var : ${conf[$var]}"
		done
	fi
}

function cmd_uninstall() {
	# $1 = profile_name | $2 = profile_number/all

	function uninstall_mn() {
		# $1 = profile_name | $2 = instance_number | $3 = total_instances

		echo -e "Uninstalling ${GREEN}$1${NC} instance ${CYAN}number $2${NC}"
		
		$coin_cli -datadir=$coin_folder$2 stop > /dev/null

		rm -rf /usr/bin/$coin_cli-$3
		rm -rf /usr/bin/$coin_daemon-$3 

		rm -rf /etc/init.d/$1-$3-init

		sed -i "/^$1=/s/=.*/=$(($3-1))/" ".dupmn/dupmn.conf"

		echo -e "#!/bin/bash\nfor (( i=0; i<=$(($3-1)); i++ )) do\n echo -e MN\$i:\n $coin_cli-\$i \$@\ndone" > /usr/bin/$coin_cli-all
		echo -e "#!/bin/bash\nfor (( i=0; i<=$(($3-1)); i++ )) do\n echo -e MN\$i:\n $coin_daemon-\$i \$@\ndone" > /usr/bin/$coin_daemon-all
		chmod +x /usr/bin/$coin_cli-all
		chmod +x /usr/bin/$coin_daemon-all

		sleep 3

		rm -rf $coin_folder$2
	}

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	local -A prof=$(get_conf .dupmn/$1)

	local count=${conf[$1]}
	local coin_cli="${prof[COIN_CLI]}"
	local coin_daemon="${prof[COIN_DAEMON]}"
	local coin_folder="${prof[COIN_FOLDER]}"
	local coin_config="${prof[COIN_CONFIG]}"

	if [ $count = 0 ]; then 
		echo -e "There aren't duplicated $1 masternodes to remove"
		exit
	fi

	if [ "$2" = "all" ]; then 
		for (( i=$count; i>=1; i-- )); do
			uninstall_mn $1 $i $i
		done
	elif [ $(is_number $2) ]; then 
		if [ $(($2)) = 0 ]; then 
			echo -e "Instance 0 is the main masternode, not a duplicated one, can't uninstall this one"
		elif [ $(($2)) -gt $(($count)) ]; then
			echo -e "Instance $(($2)) doesn't exists, there are only $count $1 instances"
		else 
			uninstall_mn $1 $(($2)) $count
			for (( i=$2+1; i<=$count; i++ )); do
				echo -e "setting ${CYAN}instance $i${NC} as ${CYAN}instance $(($i-1))${NC}..."
				$coin_cli -datadir=$coin_folder$i stop > /dev/null
				sleep 3
				#local rpc_change=$(($(grep -Po '(?<=rpcport=).*' $coin_folder$i/$coin_config)-1))
				#sed -i "/^rpcport=/s/=.*/=$rpc_change/" $coin_folder$i/$coin_config
				mv $coin_folder$i $coin_folder$(($i-1))
				$coin_daemon -datadir=$coin_folder$(($i-1)) -daemon
			done
		fi
	else 
		echo -e "Insert a number or all as parameter, not whatever \"$2\" means"
	fi
}

function cmd_rpcswap() { 
	# $1 = profile_name | $2 = instance_number | $3 = port_number
	
	if [[ ! $(is_number $2) || ! $(is_number $3) ]]; then
		echo -e "Instance and port must be numbers"
		exit
	elif [[ $(($3)) -lt 1024 || $(($3)) -gt 49151 ]]; then 
		echo -e "$3 is not a valid port (must be between 1024 and 49151)"
		exit
	fi

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	local -A prof=$(get_conf .dupmn/$1)

	local count=$((${conf[$1]}))
	local coin_cli="${prof[COIN_CLI]}"
	local coin_daemon="${prof[COIN_DAEMON]}"
	local coin_folder="${prof[COIN_FOLDER]}"
	local coin_config="${prof[COIN_CONFIG]}"

	if [[ $(($2)) -gt $count ]]; then 
		echo -e "Instance ${CYAN}number $(($2))${NC} doesn't exists, there are only $count $1 instances"
		exit
	elif [[ $(($2)) = 0 ]]; then 
		echo -e "Instance ${CYAN}number 0${NC} is the main masternode, not a duplicated one, can't change this one"
		exit
	elif [[ ! $(port_check $(($3))) ]]; then
		echo -e "Port ${RED}$(($3))${NC} seems to be in use by another process"
		exit
	fi

	$coin_cli -datadir=$coin_folder$(($2)) stop > /dev/null
	sleep 3
	sed -i "/^rpcport=/s/=.*/=$(($3))/" $coin_folder$(($2))/$coin_config
	$coin_daemon -datadir=$coin_folder$(($2)) -daemon > /dev/null

	echo -e "${GREEN}$1${NC} instance ${CYAN}number $(($2))${NC} is now listening the rpc port ${RED}$(($3))${NC}"
}

function cmd_help() {
	echo -e "Options:\n" \
			"  - dupmn profadd <prof_file> <prof_name>     Adds a profile with the given name that will be used to create duplicates of the masternode\n" \
			"  - dupmn profdel <prof_name>                 Deletes the given profile name, this will uninstall too any duplicated instance that uses this profile\n" \
			"  - dupmn install <prof_name>                 Install a new instance based on the parameters of the given profile name\n" \
			"  - dupmn list                                Shows the amount of duplicated instances of every masternode\n" \
			"  - dupmn uninstall <prof_name> <number>      Uninstall the specified instance of the given profile name\n" \
			"  - dupmn uninstall <prof_name> all           Uninstall all the duplicated instances of the given profile name (but not the main instance)\n" \
			"  - dupmn rpcswap <prof_name> <number> <port> Swaps the RPC port used of the given number instance with the new one if it's not in use or reserved"
}

function main() {

	function prof_exists() {
		# $1 = profile_name
		if [ ! -f ".dupmn/$1" ]; then
			echo -e "$1 profile hasn't been added"
			exit
		fi
	}

	if [ -z "$1" ]; then
		cmd_help
		exit
	fi

	case "$1" in
		"profadd") 
			if [ -z "$3" ]; then
				echo -e "dupmn profadd <prof_file> <coin_name> requires a profile file and a new profile name as parameters"
				exit
			fi
			cmd_profadd "$2" "$3"
			;;
		"profdel")
			if [ -z "$2" ]; then 
				echo -e "dupmn profadd <prof_name> requires a profile name as parameter"
				exit
			fi
			prof_exists "$2"
			cmd_profdel "$2"
			;;
		"install") 
			if [ -z "$2" ]; then
				echo -e "dupmn install <coin_name> requires a profile name of an added profile as a parameter"
				exit
			fi
			prof_exists "$2"
			cmd_install "$2"
			;;
		"list") 
			cmd_list
			;;
		"uninstall") 
			if [ -z "$3" ]; then 
				echo -e "dupmn uninstall <coin_name> <param> requires a profile name and a number (or all) as parameters"
				exit
			fi
			prof_exists "$2"
			cmd_uninstall "$2" "$3"
			;;
		"rpcswap")
			if [ -z "$4" ]; then 
				echo -e "dupmn rpcswap <prof_name> <coin_name> <number> requires a profile name, instance number and a port number as parameters"
				exit
			fi
			prof_exists "$2"
			cmd_rpcswap "$2" "$3" "$4"
			;;
		"help") 
			cmd_help
			;;
		*)  
			echo -e "Unrecognized parameter: $1\n"
			cmd_help
			;;
	esac
}

main $@


