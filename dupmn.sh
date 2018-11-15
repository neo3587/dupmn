#!/bin/bash

CYAN='\033[1;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function get_conf() {
	local str_map="( ";
	for line in `sed '/^$/d' $1`; do
		str_map+="[${line%=*}]=${line#*=} "
	done
	str_map+=" )"
	echo -e "$str_map"
}

function cmd_profadd() {
	
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

function cmd_install() {
	
	if [ ! -f ".dupmn/$1" ]; then
		echo -e "$1 profile hasn't been added"
		exit
	fi

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
	local new_rpc=$(($(grep -Po '(?<=rpcport=).*' $coin_folder/$coin_config)+$count))
	local new_folder="$coin_folder$count"

	mkdir $new_folder
	cp $coin_folder/$coin_config $new_folder

	sed -i "/^rpcport=/s/=.*/=$new_rpc/" $new_folder/$coin_config
	sed -i "/^listen=/s/=.*/=0/" $new_folder/$coin_config
	sed -i "/^masternodeprivkey=/s/=.*/=$new_key/" $new_folder/$coin_config

	echo -e "#\!/bin/bash\n$coin_cli \$@" > /usr/bin/$coin_cli-0
	echo -e "#\!/bin/bash\n$coin_daemon \$@" > /usr/bin/$coin_daemon-0
	echo -e "#\!/bin/bash\n$coin_cli -datadir=$new_folder \$@" > /usr/bin/$coin_cli-$count
	echo -e "#\!/bin/bash\n$coin_daemon -datadir=$new_folder \$@" > /usr/bin/$coin_daemon-$count
	echo -e "#!/bin/bash\nfor (( i=0; i<=$count; i++ )) do\n echo -e MN\$i:\n $coin_cli-\$i \$@\ndone" > /usr/bin/$coin_cli-all
	echo -e "#!/bin/bash\nfor (( i=0; i<=$count; i++ )) do\n echo -e MN\$i:\n $coin_daemon-\$i \$@\ndone" > /usr/bin/$coin_daemon-all
	chmod +x /usr/bin/$coin_cli-0
	chmod +x /usr/bin/$coin_daemon-0
	chmod +x /usr/bin/$coin_cli-$count
	chmod +x /usr/bin/$coin_daemon-$count
	chmod +x /usr/bin/$coin_cli-all
	chmod +x /usr/bin/$coin_daemon-all

	$coin_daemon -datadir=$new_folder -daemon

	sed -i "/$new_folder/d" /var/spool/cron/crontabs/root
	echo "@reboot $coin_path$coin_daemon -datadir=$new_folder -daemon" >> /var/spool/cron/crontabs/root

	sed -i "/^$1=/s/=.*/=$count/" .dupmn/dupmn.conf

	echo -e "================================================================================================================================\n" \
			"$coin_name duplicated masternode ${CYAN}number $count${NC} is up and syncing with the blockchain.\n" \
			"The duplicated masternode uses the same IP and port than the original one, but the private key is different and obviously it requires a different transaction (you cannot have 2 masternodes with the same transaction).\n" \
			"Start: ${RED}$coin_daemon-$count -daemon${NC}\n" \
			"Stop:  ${RED}$coin_cli-$count stop${NC}\n" \
			"DUPLICATED MASTERNODE PRIVATEKEY is: ${GREEN}$new_key${NC}\n" \
			"Wait until the duplicated masternode is synced with the blockchain before trying to start it.\n" \
			"For check masternode status just use: ${GREEN}$coin_cli-$count masternode status${NC} (if says \"Hot Node\" => synced).\n" \
			"Note: ${GREEN}$coin_cli-0${NC} and ${GREEN}$coin_daemon-0${NC} are just a reference to the 'main masternode', not a duplicated one.\n" \
			"Note 2: You can use ${GREEN}$coin_cli-all [parameters]${NC} and ${GREEN}$coin_daemon-all [parameters]${NC} to apply the parameters on all masternodes. Example: ${GREEN}$coin_cli-all masternode status${NC}\n" \
			"================================================================================================================================"
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
	
	function uninstall_mn() {
		
		echo -e "Uninstalling ${GREEN}$1${NC} instance ${CYAN}number $2${NC}"
		
		$coin_cli-$2 stop

		rm -rf /usr/bin/$coin_cli-$3
		rm -rf /usr/bin/$coin_daemon-$3

		sed -i "/$coin_folder$3/d" /var/spool/cron/crontabs/root
		sed -i "/^$1=/s/=.*/=$(($3-1))/" ".dupmn/dupmn.conf"

		echo -e "#\!/bin/bash\nfor (( i=0; i<=$(($3-1)); i++ )) do\n $coin_cli-$i \$@\necho -e MN$i:\ndone" > /usr/bin/$coin_cli-all
		echo -e "#\!/bin/bash\nfor (( i=0; i<=$(($3-1)); i++ )) do\n $coin_daemon-$i \$@\necho -e MN$i:\ndone" > /usr/bin/$coin_daemon-all
		chmod +x /usr/bin/$coin_cli-all
		chmod +x /usr/bin/$coin_daemon-all

		sleep 3

		rm -rf $coin_folder$2
	}

	if [ ! -f ".dupmn/$1" ]; then
		echo -e "$1 profile hasn't been added"
		exit
	fi

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
	elif [[ $2 =~ ^[0-9]+$ ]]; then 
		if [ $(($2)) = 0 ]; then 
			echo -e "Instance 0 is the main masternode, not a duplicated one, can't uninstall this one"
		elif [ $(($2)) -gt $(($count)) ]; then
			echo -e "Instance $(($2)) doesn't exists, there are only $count $1 instances"
		else 
			uninstall_mn $1 $(($2)) $count
			for (( i=$2+1; i<=$count; i++ )); do
				echo -e "setting ${CYAN}instance $i${NC} as ${CYAN}instance $(($i-1))${NC}..."
				$coin_cli -datadir=$coin_folder$i stop
				sleep 3
				local rpc_change=$(($(grep -Po '(?<=rpcport=).*' $coin_folder$i/$coin_config)-1))
				sed -i "/^rpcport=/s/=.*/=$rpc_change/" $coin_folder$i/$coin_config
				mv $coin_folder$i $coin_folder$(($i-1))
				sleep 1
				$coin_daemon -datadir=$coin_folder$(($i-1)) -daemon
			done
		fi
	else 
		echo -e "Insert a number or all as parameter, not whatever \"$2\" means"
	fi
}

function cmd_help() {
	echo -e "Options:\n" \
			"  - dupmn profadd <prof_file> <prof_name>  Adds a profile with the given name that will be used to\n" \
			"                                           create duplicates of the masternode\n" \
			"  - dupmn install <prof_name>              Install a new instance based on the parameters of the\n" \
			"                                           given profile name\n" \
			"  - dupmn list                             Shows the amount of duplicated instances of every masternode\n" \
			"  - dupmn uninstall <prof_name> <number>   Uninstall the specified instance of the given profile name\n" \
			"  - dupmn uninstall <prof_name> all        Uninstall all the duplicated instances of the given profile\n" \
			"                                           name (but not the main instance)"
}

function main() {

	if [ -z "$1" ]; then
		cmd_help
		exit
		echo -e ""
	fi

	case "$1" in
		"profadd") 
			if [ -z "$3" ]; then
				echo -e "dupmn profadd <prof_file> <coin_name> requires a profile file and a new coin name as parameters"
				exit
			fi
			cmd_profadd "$2" "$3"
			;;
		"install") 
			if [ -z "$2" ]; then
				echo -e "dupmn install <coin_name> requires a coin name of an added profile as a parameter"
				exit
			fi
			cmd_install $2
			;;
		"list") 
			cmd_list
			;;
		"uninstall") 
			if [ -z "$3" ]; then 
				echo -e "dupmn uninstall <coin_name> <param> requires a coin name and a number (or all) as parameters"
				exit
			fi
			cmd_uninstall $2 $3
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

