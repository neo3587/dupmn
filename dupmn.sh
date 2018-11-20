#!/bin/bash

# TODO:
#  - Add a command to swap instance numbers


CYAN='\033[1;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

	sed -i "/^$1=/s/=.*/=$count/" .dupmn/dupmn.conf

	configure_systemd $1 $count

	echo -e "===================================================================================================\
			\n$coin_name duplicated masternode ${CYAN}number $count${NC} is up and syncing with the blockchain.\
			\nThe duplicated masternode uses the same IP and port than the original one, but the private key is different and obviously it requires a different transaction (you cannot have 2 masternodes with the same transaction).\
			\nNew RPC port is ${CYAN}$new_rpc${NC} (other programs may not be able to use this port, but you can change it with ${RED}dupmn rpcchange $1 $count PORT_NUMBER${NC})\
			\nStart: ${RED}systemctl start $1-$count.service${NC}\
			\nStop:  ${RED}systemctl stop $1-$count.service${NC}\
			\nDUPLICATED MASTERNODE PRIVATEKEY is: ${GREEN}$new_key${NC}\
			\nWait until the duplicated masternode is synced with the blockchain before trying to start it.\
			\nFor check masternode status just use: ${GREEN}$coin_cli-$count masternode status${NC} (if says \"Hot Node\" => synced).\
			\nNote: ${GREEN}$coin_cli-0${NC} and ${GREEN}$coin_daemon-0${NC} are just a reference to the 'main masternode', not a duplicated one.\
			\nNote 2: You can use ${GREEN}$coin_cli-all [parameters]${NC} and ${GREEN}$coin_daemon-all [parameters]${NC} to apply the parameters on all masternodes. Example: ${GREEN}$coin_cli-all masternode status${NC}\
			\n==================================================================================================="
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
	# $1 = profile_name | $2 = instance_number/all

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	local -A prof=$(get_conf .dupmn/$1)

	local count=${conf[$1]}

	local coin_name="${prof[COIN_NAME]}"
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
			echo -e "Uninstalling ${GREEN}$1${NC} instance ${CYAN}number $i${NC}"
			rm -rf /usr/bin/$coin_cli-$i
			rm -rf /usr/bin/$coin_daemon-$i
			systemctl stop $coin_name-$i.service > /dev/null
			systemctl disable $coin_name-$i.service > /dev/null 2>&1
			sleep 3
			rm -rf /etc/systemd/system/$coin_name-$i.service
			rm -rf $coin_folder$i
		done
		sed -i "/^$1=/s/=.*/=0/" ".dupmn/dupmn.conf"
		echo -e "#!/bin/bash\nfor (( i=0; i<=0; i++ )) do\n echo -e MN\$i:\n $coin_cli-\$i \$@\ndone" > /usr/bin/$coin_cli-all
		echo -e "#!/bin/bash\nfor (( i=0; i<=0; i++ )) do\n echo -e MN\$i:\n $coin_daemon-\$i \$@\ndone" > /usr/bin/$coin_daemon-all
		chmod +x /usr/bin/$coin_cli-all
		chmod +x /usr/bin/$coin_daemon-all
		systemctl daemon-reload
	elif [ $(is_number $2) ]; then 
		if [ $(($2)) = 0 ]; then 
			echo -e "Instance 0 is the main masternode, not a duplicated one, can't uninstall this one"
		elif [ $(($2)) -gt $(($count)) ]; then
			echo -e "Instance $(($2)) doesn't exists, there are only $count $1 instances"
		else 
			echo -e "Uninstalling ${GREEN}$1${NC} instance ${CYAN}number $(($2))${NC}"
			rm -rf /usr/bin/$coin_cli-$(($count))
			rm -rf /usr/bin/$coin_daemon-$(($count))
			$coin_cli -datadir=$coin_folder$(($2)) stop > /dev/null
			sed -i "/^$1=/s/=.*/=$(($count-1))/" ".dupmn/dupmn.conf"
			echo -e "#!/bin/bash\nfor (( i=0; i<=$(($count-1)); i++ )) do\n echo -e MN\$i:\n $coin_cli-\$i \$@\ndone" > /usr/bin/$coin_cli-all
			echo -e "#!/bin/bash\nfor (( i=0; i<=$(($count-1)); i++ )) do\n echo -e MN\$i:\n $coin_daemon-\$i \$@\ndone" > /usr/bin/$coin_daemon-all
			chmod +x /usr/bin/$coin_cli-all
			chmod +x /usr/bin/$coin_daemon-all
			sleep 3
			rm -rf $coin_folder$2
			
			for (( i=$2; i<=$count; i++ )); do
				systemctl stop $coin_name-$i.service 
			done
			for (( i=$2+1; i<=$count; i++ )); do
				echo -e "setting ${CYAN}instance $i${NC} as ${CYAN}instance $(($i-1))${NC}..."
				mv $coin_folder$i $coin_folder$(($i-1))
				sleep 1
				systemctl start $coin_name-$(($i-1)).service 
			done

			systemctl disable $coin_name-$count.service > /dev/null 2>&1
			sleep 3
			rm -rf /etc/systemd/system/$coin_name-$count.service
			systemctl daemon-reload
		fi
	else 
		echo -e "Insert a number or all as parameter, not whatever \"$2\" means"
	fi
}

function cmd_rpcchange() { 
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
	local coin_name="${prof[COIN_NAME]}"
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

	systemctl stop $coin_name-$(($2)).service > /dev/null
	sleep 3
	sed -i "/^rpcport=/s/=.*/=$(($3))/" $coin_folder$(($2))/$coin_config
	systemctl start $coin_name-$(($2)).service

	echo -e "${GREEN}$1${NC} instance ${CYAN}number $(($2))${NC} is now listening the rpc port ${RED}$(($3))${NC}"
}

function cmd_swapfile() {
	# $1 = size_in_mbytes

	if [[ ! $(is_number $1) ]]; then 
		echo -e "Size_in_mbytes must be a number"
		exit
	fi

	local avail_mb=$(df / --output=avail -m | grep [0-9])
	local total_mb=$(df / --output=size -m | grep [0-9])

	if [[ $(($1)) -ge $(($avail_mb)) ]]; then 
		echo -e "There's only $(($avail_mb)) MB available in the hard disk (NOTE: recommended to use a swapfile of NUMBER_OF_MASTERNODES * 150 MB)"
		exit
	fi

	echo -e "All duplicated instances will be temporary disabled until the swapfile command is finished to decrease the pressure on RAM..."

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	for x in "${!conf[@]}"; do
		local -A prof=$(get_conf .dupmn/$x)
		for (( i=1; i<=${conf[$x]}; i++ )); do
			systemctl stop ${prof[COIN_NAME]}-$i.service 
			sleep 1
		done
	done

	if [[ -f /mnt/dupmn_swapfile ]]; then
		swapoff /mnt/dupmn_swapfile > /dev/null
	fi

	if [[ $(($1)) = 0 ]]; then 
		rm -rf /mnt/dupmn_swapfile 
		echo -e "Swapfile deleted"
	else
		dd if=/dev/zero of=/mnt/dupmn_swapfile bs=1024 count=$(($1 * 1024)) > /dev/null 2>&1
		chmod 600 /mnt/dupmn_swapfile > /dev/null 2>&1
		mkswap /mnt/dupmn_swapfile > /dev/null 2>&1
		swapon /mnt/dupmn_swapfile > /dev/null 2>&1
		/mnt/dupmn_swapfile swap swap defaults 0 0 > /dev/null 2>&1
		echo -e "Swapfile new size = ${GREEN}$(($1)) MB${NC}"
	fi

	echo -e "Reenabling instances... (you don't need to activate them again from your wallet and your position in the mn pool reward won't be lost)"
	for x in "${!conf[@]}"; do
		local -A prof=$(get_conf .dupmn/$x)
		for (( i=1; i<=${conf[$x]}; i++ )); do
			systemctl start ${prof[COIN_NAME]}-$i.service
			sleep 2
		done
	done

	echo -e "Use ${YELLOW}free -m${NC} to see the changes of your swapfile"
}

function cmd_help() {
	echo -e "Options:\n" \
			"  - ${YELLOW}dupmn profadd <prof_file> <prof_name>       ${NC}Adds a profile with the given name that will be used to create duplicates of the masternode\n" \
			"  - ${YELLOW}dupmn profdel <prof_name>                   ${NC}Deletes the given profile name, this will uninstall too any duplicated instance that uses this profile\n" \
			"  - ${YELLOW}dupmn install <prof_name>                   ${NC}Install a new instance based on the parameters of the given profile name\n" \
			"  - ${YELLOW}dupmn list                                  ${NC}Shows the amount of duplicated instances of every masternode\n" \
			"  - ${YELLOW}dupmn uninstall <prof_name> <number>        ${NC}Uninstall the specified instance of the given profile name\n" \
			"  - ${YELLOW}dupmn uninstall <prof_name> all             ${NC}Uninstall all the duplicated instances of the given profile name (but not the main instance)\n" \
			"  - ${YELLOW}dupmn rpcchange <prof_name> <number> <port> ${NC}Changes the RPC port used from the given number instance with the new one if it's not in use or reserved\n" \
			"  - ${YELLOW}dupmn swapfile <size_in_mbytes>             ${NC}Creates, changes or deletes (if parameter is 0) a swapfile of the given size in MB to increase the virtual memory" 
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
		"rpcchange")
			if [ -z "$4" ]; then 
				echo -e "dupmn rpcchange <prof_name> <number> <port> requires a profile name, instance number and a port number as parameters"
				exit
			fi
			prof_exists "$2"
			cmd_rpcchange "$2" "$3" "$4"
			;;
		"swapfile")
			if [ -z "$2" ]; then 
				echo -e "dupmn swapfile <size_in_mbytes> requires a number as parameter"
				exit
			fi
			cmd_swapfile "$2"
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

