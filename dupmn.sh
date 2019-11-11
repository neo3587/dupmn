#!/bin/bash

# Author: neo3587
# Source: https://github.com/neo3587/dupmn

# TODO:
# - FORCE_IPV6=1 => auto choose/add a IPv6 when creating on dupmn install
# - dupmn install <prof_name> -c NUMBER | --count=NUMBER ?? => privkey array, print "MN + dupe_offset : privkey[i]"
# - check and test memory reduction .conf parameters
# - check dupmn list [prof] JSON API bugs on unexpected MN values


readonly GRAY='\e[1;30m'
readonly DARKRED='\e[0;31m'
readonly RED='\e[1;31m'
readonly DARKGREEN='\e[0;32m'
readonly GREEN='\e[1;32m'
readonly DARKYELLOW='\e[0;33m'
readonly YELLOW='\e[1;33m'
readonly DARKBLUE='\e[0;34m'
readonly BLUE='\e[1;34m'
readonly DARKMAGENTA='\e[0;35m'
readonly MAGENTA='\e[1;35m'
readonly DARKCYAN='\e[0;36m'
readonly CYAN='\e[1;36m'
readonly UNDERLINE='\e[1;4m'
readonly NC='\e[0m'


PROFILE_NAME=""
COIN_NAME=""
COIN_DAEMON=""
COIN_CLI=""
COIN_FOLDER=""
COIN_CONFIG=""
RPC_PORT=""
COIN_SERVICE=""
DUP_COUNT=""
EXEC_COIN_CLI=""
EXEC_COIN_DAEMON=""
IP=""
IP_TYPE=""
NEW_RPC=""
NEW_KEY=""
INSTALL_BOOTSTRAP=""
FORCE_LISTEN=""


function echo_json() {
	[[ -t 3 ]] && echo -e "$1" >&3
}
function json_bool() {
	[[ $1 ]] && echo true || echo false
}
function array_join() {
	# <$1 = delimiter> | <$2* = params>
	local IFS="$1"
	shift
	echo "$*"
}
function load_profile() {
	# <$1 = profile_name> | [$2 = check_exec]

	if [[ ! -f ".dupmn/$1" ]]; then
		echo -e "${BLUE}$1${NC} profile hasn't been added"
		echo_json "{\"error\":\"profile hasn't been added\",\"errcode\":100}"
		exit
	fi

	local -A prof=$(get_conf .dupmn/$1)
	local -A conf=$(get_conf .dupmn/dupmn.conf)

	local CMD_ARRAY=(COIN_NAME COIN_DAEMON COIN_CLI COIN_FOLDER COIN_CONFIG)
	for var in "${CMD_ARRAY[@]}"; do
		if [[ ! "${!prof[@]}" =~ "$var" || -z "${prof[$var]}" ]]; then
			echo -e "Seems like you modified something that was supposed to remain unmodified: ${MAGENTA}$var${NC} parameter should exists and have a assigned value in ${GREEN}.dupmn/$1${NC} file"
			echo -e "You can fix it by adding the ${BLUE}$1${NC} profile again"
			echo_json "{\"error\":\"profile modified\",\"errcode\":101}"
			exit
		fi
	done
	if [[ ! "${!conf[@]}" =~ "$1" || -z "${conf[$1]}" || ! $(is_number "${conf[$1]}") ]]; then
		echo -e "Seems like you modified something that was supposed to remain unmodified: ${MAGENTA}$1${NC} parameter should exists and have a assigned number in ${GREEN}.dupmn/dupmn.conf${NC} file"
		echo -e "You can fix it by adding ${MAGENTA}$1=0${NC} to the .dupmn/dupmn.conf file (replace the number 0 for the number of nodes installed with dupmn using the ${BLUE}$1${NC} profile)"
		echo_json "{\"error\":\"dupmn.conf modified\",\"errcode\":102}"
		exit
	fi

	PROFILE_NAME="$1"
	COIN_NAME="${prof[COIN_NAME]}"
	COIN_DAEMON="${prof[COIN_DAEMON]}"
	COIN_CLI="${prof[COIN_CLI]}"
	COIN_FOLDER="${prof[COIN_FOLDER]}"
	COIN_CONFIG="${prof[COIN_CONFIG]}"
	RPC_PORT="${prof[RPC_PORT]}"
	COIN_SERVICE="${prof[COIN_SERVICE]}"
	DUP_COUNT=$(stoi ${conf[$1]})
	EXEC_COIN_DAEMON="${prof[COIN_PATH]}$COIN_DAEMON"
	EXEC_COIN_CLI="${prof[COIN_PATH]}$COIN_CLI"
	FORCE_LISTEN="${prof[FORCE_LISTEN]}"

	if [[ $2 -eq 1 ]]; then
		if [[ ! -f "$EXEC_COIN_DAEMON" ]]; then
			EXEC_COIN_DAEMON=$(which $COIN_DAEMON)
			if [[ ! -f "$EXEC_COIN_DAEMON" ]]; then
				echo -e "Can't locate ${GREEN}$COIN_DAEMON${NC}, it must be at the defined path from ${CYAN}\"COIN_PATH\"${NC} or in ${CYAN}/usr/bin/${NC} or ${CYAN}/usr/local/bin/${NC}"
				echo_json "{\"error\":\"coin daemon can't be found\",\"errcode\":103}"
				exit
			fi
		fi
		if [[ ! -f "$EXEC_COIN_CLI" ]]; then
			EXEC_COIN_CLI=$(which $COIN_CLI)
			if [[ ! -f "$EXEC_COIN_CLI" ]]; then
				echo -e "Can't locate ${GREEN}$COIN_CLI${NC}, it must be at the defined path from ${CYAN}\"COIN_PATH\"${NC} or in ${CYAN}/usr/bin/${NC} or ${CYAN}/usr/local/bin/${NC}"
				echo_json "{\"error\":\"coin cli can't be found\",\"errcode\":104}"
				exit
			fi
		fi
	fi
}
function get_conf() {
	# <$1 = conf_file>
	local str_map="";
	for line in `sed '/^$/d' $1`; do
		str_map+="[${line%=*}]=${line#*=} "
	done
	echo -e "( $str_map )"
}
function port_check() {
	# <$1 = port_number>
	[[ ! $(lsof -Pi :$1 -sTCP:LISTEN -t) ]] && echo "1"
}
function find_port() {
	# <$1 = initial_check>

	function port_check_loop() {
		for (( i=$1; i<=$2; i++ )); do
			if [[ ! "${3}[@]" =~ "${i}" && $(port_check $i) ]]; then
				echo -e "$i"
				return
			fi
		done
	}

	local dup_ports="$(conf_get_value $COIN_FOLDER/$COIN_CONFIG port)"
	[[ ! $(is_number $dup_ports) ]] && dup_ports=$(conf_get_value $COIN_FOLDER/$COIN_CONFIG "masternodeaddr" | rev | cut -d : -f1 | rev)
	[[ ! $(is_number $dup_ports) ]] && dup_ports=$(conf_get_value $COIN_FOLDER/$COIN_CONFIG "externalip"     | rev | cut -d : -f1 | rev)
	for (( i=1; i<=$DUP_COUNT; i++ )); do
		dup_ports="$dup_ports $(conf_get_value $COIN_FOLDER$i/$COIN_CONFIG rpcport) "
	done
	local port=$(port_check_loop $1 49151 "( $dup_ports )")
	[[ $port ]] && echo $port || echo $(port_check_loop 1024 $1 "( $dup_ports )")
}
function is_number() {
	# <$1 = number>
	[[ "$1" =~ ^[0-9]+$ ]] && echo "1"
}
function configure_systemd() {
	# [$1 = instance_number]

	local service_name=$([[ $1 ]] && echo $COIN_NAME-$1 || echo $COIN_NAME)

	echo -e "[Unit]\
	\nDescription=$service_name service\
	\nAfter=network.target\
	\n\
	\n[Service]\
	\nUser=root\
	\nGroup=root\
	\nType=forking\
	\nExecStart=$EXEC_COIN_DAEMON -daemon -conf=$COIN_FOLDER$1/$COIN_CONFIG -datadir=$COIN_FOLDER$1\
	\nExecStop=$EXEC_COIN_CLI -conf=$COIN_FOLDER$1/$COIN_CONFIG -datadir=$COIN_FOLDER$1 stop\
	\nRestart=always\
	\nPrivateTmp=true\
	\nTimeoutStopSec=60s\
	\nTimeoutStartSec=10s\
	\nStartLimitInterval=120s\
	\nStartLimitBurst=5\
	\n\
	\n[Install]\
	\nWantedBy=multi-user.target" > /etc/systemd/system/$service_name.service
	chmod +x /etc/systemd/system/$service_name.service

	systemctl daemon-reload
	[[ $1 ]] && systemctl start $service_name.service && sleep 1
	systemctl enable $service_name.service &> /dev/null

	if [[ $1 && ! "$(ps axo cmd:100 | egrep $service_name)" ]]; then
		echo -e "\n${RED}IMPORTANT!!!${NC} \
			\nSeems like there might be a problem with the systemctl configuration, please investigate.\
			\nYou should start by running the following commands:\
			\n${GREEN}systemctl start  $service_name.service${NC}\
			\n${GREEN}systemctl status $service_name.service${NC}\
			\n${GREEN}less /var/log/syslog${NC}\
			\nThe most common causes of this might be that either you made something to a file that dupmn modifies or creates, or that you don't have enough free resources (usually memory).
			\nThere's also the chance that this could be a false positive error (so actually everything is ok), anyway please use the commands above to investigate."
	fi
}
function wallet_cmd() {
	# <$1 = start|stop|loaded> | [$2 = dup_number] | [$3 = wait_timeout(loaded)]
	exec 2> /dev/null

	function wallet_loaded() {
		local timer=$([[ $2 ]] && echo $2 || echo 0)
		for (( i=0; i<=$timer; i++ )); do
			[[ $(is_number $($(exec_coin cli $1) getblockcount)) ]] && echo "1" && break
			sleep 1
		done
	}

	local service=$([[ $2 -gt 0 ]] && echo "$COIN_NAME-$2.service" || echo "$COIN_SERVICE")

	case "$1" in
		"loaded")
			wallet_loaded $2 $3
			;;
		"start")
			if [[ ! $(wallet_loaded $2) ]]; then
				systemctl start $service &> /dev/null
				[[ $(wallet_loaded $2 30) ]] && echo "1"
			fi
			;;
		"stop")
			if [[ $(wallet_loaded $2) ]]; then
				systemctl stop $service &> /dev/null
				[[ $($(exec_coin cli $2) stop) ]] && sleep 3
				echo "1"
			fi
			;;
	esac

	exec 2> /dev/tty
}
function exec_coin() {
	# <$1 = daemon|cli> | [$2 = dup_number]
	local use_cmd=$([[ $1 == "daemon" ]] && echo $([[ $2 -gt 0 ]] && echo $COIN_DAEMON-$2 || echo $EXEC_COIN_DAEMON) \
		  || echo $([[ $1 == "cli"    ]] && echo $([[ $2 -gt 0 ]] && echo $COIN_CLI-$2    || echo $EXEC_COIN_CLI)))
	[[ ! $use_cmd ]] && echo "DEBUG ERROR exec_coin passed parameter: $1" && exit || echo $use_cmd
}
function get_folder() {
	echo $COIN_FOLDER$([[ $1 -gt 0 ]] && echo $1 || echo "")/
}
function try_cmd() {
	# <$1 = exec> | <$2 = try> | <$3 = catch>
	exec 2> /dev/null
	local check=$($1 $2)
	[[ "$check" ]] && echo $check || echo $($1 $3)
	exec 2> /dev/tty
}
function conf_set_value() {
	# <$1 = conf_file> | <$2 = key> | <$3 = value> | [$4 = force_create]
	#[[ $(grep -ws "^$2" "$1" | cut -d "=" -f1) == "$2" ]] && sed -i "/^$2=/s/=.*/=$3/" "$1" || ([[ "$4" == "1" ]] && echo -e "$2=$3" >> $1)
	local key_line=$(grep -ws "^$2" "$1")
	[[ "$(echo $key_line | cut -d '=' -f1)" == "$2" ]] && sed -i "/^$2\s*=/c $2=$3" $1 || $([[ "$4" == "1" ]] && echo -e "$2=$3" >> $1)
}
function conf_get_value() {
	# <$1 = conf_file> | <$2 = key> | [$3 = limit]
	[[ "$3" == "0" ]] && grep -ws "^$2" "$1" | cut -d "=" -f2 || grep -ws "^$2" "$1" | cut -d "=" -f2 | head $([[ ! $3 ]] && echo "-1" || echo "-$3")
}
function make_chmod_file() {
	# <$1 = file> | <$2 = content>
	echo -e "$2" > $1
	chmod +x $1
}
function stoi() {
	# <$1 = number>
	[[ $(is_number $1) ]] && echo $1 | awk '{ printf "%d\n", $0 }' || echo $1
}
function get_ips() {
	# <$1 = 4 or 6> | [$2 = netmask] | [$3 = interface]
	local get_ip=$(ip -$1 addr show $3 | grep "scope global" | awk '{print $2}')
	[[ $2 != 1 ]] && echo -e $get_ip | cut -d / -f1 || echo -e $get_ip
}
function netmask_cidr() {
	# <$1 = netmask>
	if [[ $(echo $1 | grep -w -E -o '^(254|252|248|240|224|192|128)\.0\.0\.0|255\.(254|252|248|240|224|192|128|0)\.0\.0|255\.255\.(254|252|248|240|224|192|128|0)\.0|255\.255\.255\.(255|254|252|248|240|224|192|128|0)') ]]; then
		local nbits=0
		for oct in $(echo $1 | tr "." " "); do
			while [[ $oct -gt 0 ]]; do
				oct=$(($oct << 1 & 255))
				nbits=$(($nbits+1))
			done
		done
		echo $nbits
	elif [[ $(is_number $1) ]]; then
		stoi $1
	fi
}


function cmd_profadd() {
	# <$1 = profile_file> | [$2 = profile_name]

	if [[ ! -f $1 ]]; then
		echo -e "${BLUE}$1${NC} file doesn't exists"
		echo_json "{\"error\":\"provided file doesn't exists\",\"errcode\":400}"
		return
	fi

	local -A prof=$(get_conf $1)
	local CMD_ARRAY=(COIN_NAME COIN_DAEMON COIN_CLI COIN_FOLDER COIN_CONFIG)

	for var in "${CMD_ARRAY[@]}"; do
		if [[ ! "${!prof[@]}" =~ "$var" ]]; then
			echo -e "${MAGENTA}$var${NC} doesn't exists in the supplied profile file"
			echo_json "{\"error\":\"missing variable: $var\",\"errcode\":401}"
			return
		elif [[ -z "${prof[$var]}" ]]; then
			echo -e "${MAGENTA}$var${NC} doesn't contain a value in the supplied profile file"
			echo_json "{\"error\":\"missing value: $var\",\"errcode\":402}"
			return
		fi
	done

	local prof_name=$([[ ! $2 ]] && echo ${prof[COIN_NAME]} || echo "$2")

	if [[ $prof_name == "dupmn.conf" ]]; then
		echo -e "From the infinite amount of possible names for the profile and you had to choose the only one that you can't use... for god sake..."
		echo_json "{\"error\":\"reserved profile name\",\"errcode\":403}"
		return
	elif [[ ${prof_name:0:1} == "-" ]]; then
		echo -e "Profile name cannot start with a dash ${RED}-${NC} character"
		echo_json "{\"error\":\"reserved profile name\",\"errcode\":403}"
		return
	fi

	[[ ! -d ~/.dupmn ]] && mkdir ~/.dupmn
	[[ ! -f ~/.dupmn/dupmn.conf ]] && touch ~/.dupmn/dupmn.conf
	[[ $(conf_get_value ~/.dupmn/dupmn.conf $prof_name) ]] || $(conf_set_value ~/.dupmn/dupmn.conf $prof_name 0 1)

	cp $1 ~/.dupmn/$prof_name

	local fix_path=${prof[COIN_PATH]}
	local fix_folder=${prof[COIN_FOLDER]}

	if [[ ${fix_path:${#fix_path}-1:1} != "/" ]]; then
		sed -i "/^COIN_PATH=/s/=.*/=\"${fix_path//"/"/"\/"}\/\"/" ~/.dupmn/$prof_name
	fi
	if [[ ${fix_folder:${#fix_folder}-1:1} == "/" ]]; then
		fix_folder=${fix_folder::-1}
		sed -i "/^COIN_FOLDER=/s/=.*/=\"${fix_folder//"/"/"\/"}\"/" ~/.dupmn/$prof_name
	fi

	echo -e "${BLUE}$prof_name${NC} profile successfully added, use ${GREEN}dupmn install $prof_name${NC} to create a new instance of the masternode"

	local retcode=0
	if [[ -z "${prof[COIN_SERVICE]}" ]]; then
		echo -e "\n${YELLOW}WARNING:${NC} The provided profile doesn't have a ${CYAN}\"COIN_SERVICE\"${NC} parameter, the dupmn script won't be able to stop the main node on some commands"
		if [[ -t 1 ]]; then
			read -r -p "Do you want to create a service for the main node? [Y/n]`echo $'\n> '`" yesno
			[[ ! $yesno =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]] && echo -e "Main node service creation cancelled" && return
		fi
		if [[ -f /etc/systemd/system/${prof[COIN_NAME]}.service ]]; then
			echo -e "${YELLOW}WARNING:${NC} There seems to be already a ${CYAN}${prof[COIN_NAME]}.service${NC} in ${MAGENTA}/etc/systemd/system/${NC}" 
			if [[ -t 1 ]]; then
				read -r -p "Do you want to use it for the main MN? [Y/n]`echo $'\n> '`" yesno
				[[ $yesno =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]] && echo -e "${CYAN}${prof[COIN_NAME]}.service${NC} set as main node service" || return
			fi
			conf_set_value ~/.dupmn/$prof_name "COIN_SERVICE" "\"${prof[COIN_NAME]}.service\"" 1
			retcode=1
		elif [[ $(load_profile "$prof_name" 1 3>/dev/null) ]]; then
			echo -e "${RED}ERROR:${NC} Can't find the binaries of the main node to make the service, make sure that you have installed the masternode and retry this command to create a service"
			retcode=2
		else
			load_profile "$prof_name" 1 3>/dev/null
			configure_systemd
			conf_set_value ~/.dupmn/$prof_name "COIN_SERVICE" "\"${prof[COIN_NAME]}.service\"" 1
			echo -e "Service for ${BLUE}$prof_name${NC} main node created"
			retcode=3
		fi
	fi

	echo_json "{\"message\":\"profile successfully added\",\"retcode\":$retcode}"
}
function cmd_profdel() {

	local deleted_dupes=$DUP_COUNT
	if [[ $DUP_COUNT -gt 0 ]]; then
		if [[ -t 1 ]]; then
			read -r -p "All the dupes created with this profile will be deleted, are you sure to apply this command? [Y/n]`echo $'\n> '`" yesno
			if [[ ! $yesno =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]; then
				echo -e "Profile deletion cancelled"
				echo_json "{\"message\":\"profile deletion cancelled\",\"deleted\":false,\"count\":0}"
				return
			fi
		fi
		cmd_uninstall $1 all 3>/dev/null
	fi
	sed -i "/$PROFILE_NAME\=/d" .dupmn/dupmn.conf
	sed -i "/^$/d"   .dupmn/dupmn.conf

	rm -rf /usr/bin/$COIN_DAEMON-0
	rm -rf /usr/bin/$COIN_DAEMON-all
	rm -rf /usr/bin/$COIN_CLI-0
	rm -rf /usr/bin/$COIN_CLI-all
	rm -rf .dupmn/$PROFILE_NAME

	echo_json "{\"message\":\"profile successfully deleted\",\"deleted\":true,\"count\":$deleted_dupes}"
}
function cmd_install() {
	# <$1 = instance_number>

	if [ ! -f "$COIN_FOLDER/$COIN_CONFIG" ]; then
		echo -e "$COIN_FOLDER/$COIN_CONFIG folder can't be found, $COIN_NAME is not installed in the system or the given profile has a wrong parameter"
		echo_json "{\"error\":\"Can't find coin config\",\"errcode\":500}" 
		exit
	elif [[ $FORCE_LISTEN == "1" && ! $IP ]]; then
		echo -e "${RED}ERROR:${NC} A profile with ${MAGENTA}FORCE_LISTEN=1${NC} requires a IP with -ip=IP extra parameter when installing a dupe"
		echo_json "{\"error\":\"A profile with FORCE_LISTEN=1 requires a IP when installing a dupe\",\"errcode\":501}" 
		exit
	fi

	local new_folder="$COIN_FOLDER$1"
	local retcode=0

	# install_proc main

	if [[ ! $NEW_KEY ]]; then
		for (( i=0; i<=$DUP_COUNT; i++ )); do
			if [[ $(wallet_cmd loaded $i) ]]; then
				NEW_KEY=$(try_cmd $(exec_coin cli $i) "createmasternodekey" "masternode genkey")
				break
			fi
		done
	fi
	if [[ ! $NEW_RPC ]]; then
		NEW_RPC=$([[ $RPC_PORT ]] && echo $RPC_PORT || conf_get_value $COIN_FOLDER/$COIN_CONFIG "rpcport")
		NEW_RPC=$(find_port $(($([[ $NEW_RPC ]] && stoi $NEW_RPC || echo 1023)+1)))
	fi

	mkdir $new_folder &> /dev/null
	cp $COIN_FOLDER/$COIN_CONFIG $new_folder

	local new_user=$(conf_get_value $COIN_FOLDER/$COIN_CONFIG "rpcuser")
	local new_pass=$(conf_get_value $COIN_FOLDER/$COIN_CONFIG "rpcpassword")
	new_user=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $([[ ${#new_user} -gt 3 ]] && echo ${#new_user} || echo 10) | head -n 1)
	new_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $([[ ${#new_pass} -gt 6 ]] && echo ${#new_pass} || echo 22) | head -n 1)

	$(conf_set_value $new_folder/$COIN_CONFIG "rpcuser"           $new_user 1)
	$(conf_set_value $new_folder/$COIN_CONFIG "rpcpassword"       $new_pass 1)
	$(conf_set_value $new_folder/$COIN_CONFIG "rpcport"           $NEW_RPC  1)
	$(conf_set_value $new_folder/$COIN_CONFIG "listen"            0         1)
	$(conf_set_value $new_folder/$COIN_CONFIG "masternodeprivkey" $NEW_KEY  1)
	[[ ! $(grep "addnode=127.0.0.1" $new_folder/$COIN_CONFIG) ]] && echo "addnode=127.0.0.1" >> $new_folder/$COIN_CONFIG

	$(make_chmod_file /usr/bin/$COIN_CLI-0      "#!/bin/bash\n$EXEC_COIN_CLI \$@")
	$(make_chmod_file /usr/bin/$COIN_DAEMON-0   "#!/bin/bash\n$EXEC_COIN_DAEMON \$@")
	$(make_chmod_file /usr/bin/$COIN_CLI-$1     "#!/bin/bash\n$EXEC_COIN_CLI -datadir=$new_folder \$@")
	$(make_chmod_file /usr/bin/$COIN_DAEMON-$1  "#!/bin/bash\n$EXEC_COIN_DAEMON -datadir=$new_folder \$@")
	$(make_chmod_file /usr/bin/$COIN_CLI-all    "#!/bin/bash\nfor (( i=0; i<=$1; i++ )) do\n echo -e MN\$i:\n $COIN_CLI-\$i \$@\ndone")
	$(make_chmod_file /usr/bin/$COIN_DAEMON-all "#!/bin/bash\nfor (( i=0; i<=$1; i++ )) do\n echo -e MN\$i:\n $COIN_DAEMON-\$i \$@\ndone")

	$(conf_set_value .dupmn/dupmn.conf $PROFILE_NAME $1 1)

	if [[ ! $NEW_KEY ]]; then
		# main and dupes were stopped on createmasternodekey
		echo -e "Couldn't find a opened ${BLUE}$COIN_NAME${NC} wallet opened to generate a private key, temporary opening the new wallet to generate a key"
		$(conf_set_value $new_folder/$COIN_CONFIG "masternode"        "0"      1)
		$COIN_DAEMON-$1 -daemon
		wallet_cmd loaded $1 30 > /dev/null
		NEW_KEY=$(try_cmd $(exec_coin cli $1) "createmasternodekey" "masternode genkey")
		$(conf_set_value $new_folder/$COIN_CONFIG "masternodeprivkey" $NEW_KEY 1)
		$(conf_set_value $new_folder/$COIN_CONFIG "masternode"        "1"      1)
		$COIN_CLI-$1 stop
		sleep 3
	fi

	# install_proc ip

	local mn_port=$(conf_get_value $new_folder/$COIN_CONFIG "port")
	[[ ! $(is_number $mn_port) ]] && mn_port=$(conf_get_value $new_folder/$COIN_CONFIG "masternodeaddr" | rev | cut -d : -f1 | rev)
	[[ ! $(is_number $mn_port) ]] && mn_port=$(conf_get_value $new_folder/$COIN_CONFIG "externalip"     | rev | cut -d : -f1 | rev)
	[[ ! $(is_number $mn_port) ]] && mn_port=""

	if [[ $IP ]]; then 

		$(conf_set_value $new_folder/$COIN_CONFIG "externalip"     "$IP$([[ $mn_port ]] && echo :$mn_port)" 0)
		$(conf_set_value $new_folder/$COIN_CONFIG "masternodeaddr" "$IP$([[ $mn_port ]] && echo :$mn_port)" 0)

		if [[ $FORCE_LISTEN == "1" ]]; then

			$(conf_set_value $new_folder/$COIN_CONFIG "bind"   $IP 1)
			$(conf_set_value $new_folder/$COIN_CONFIG "listen" "1" 1)

			if [[ ! $(conf_get_value $COIN_FOLDER/$COIN_CONFIG "bind") ]]; then
				echo -e "Adding the ${CYAN}bind${NC} parameter to the main node conf file, this only will be applied this time..."
				local main_ip=$(echo $(conf_get_value $COIN_FOLDER/$COIN_CONFIG "masternodeaddr") | rev)
				main_ip=$([[ $main_ip ]] && echo "$main_ip" || echo $(conf_get_value $COIN_FOLDER/$COIN_CONFIG "externalip") | rev)
				main_ip=$(echo $([[ $main_ip =~ ^[0-9]{1,}\:. ]] && echo $main_ip | cut -d ':' -f2- || echo $main_ip) | rev)
				$(conf_set_value $COIN_FOLDER/$COIN_CONFIG "bind" $main_ip 1)
				if [[ $($EXEC_COIN_CLI stop 2> /dev/null) ]]; then
					sleep 5
					$EXEC_COIN_DAEMON -daemon &> /dev/null
					wallet_cmd loaded 0 20 > /dev/null
				fi
			fi
		fi
	fi

	# install_proc end

	if [[ $INSTALL_BOOTSTRAP ]]; then
		if [[ ! $(wallet_cmd loaded) || ($COIN_SERVICE && -f /etc/systemd/system/$COIN_SERVICE) ]]; then
			cmd_bootstrap 0 $1 3>/dev/null
		elif [[ $1 -ge 2 ]]; then
			echo -e "${MAGENTA}NOTE:${NC} Can't stop the main node, trying the bootstrap with the dupe ${CYAN}1${NC}"
			cmd_bootstrap 1 $1 3>/dev/null
		elif [[ $DUP_COUNT -ge 2 && $1 -eq 1 ]]; then # only for reinstall
			echo -e "${MAGENTA}NOTE:${NC} Can't stop the main node, trying the bootstrap with the dupe ${CYAN}2${NC}"
			cmd_bootstrap 2 $1 3>/dev/null
		else
			echo -e "${YELLOW}WARNING:${NC} Can't automatically apply the bootstrap, use ${GREEN}dupmn bootstrap${NC} manually"
			((retcode+=1))
		fi
	fi

	configure_systemd $1

	local show_ip=$IP
	[[ ! $show_ip ]] && show_ip=$(conf_get_value $new_folder/$COIN_CONFIG "masternodeaddr" | cut -d : -f1)
	[[ ! $show_ip ]] && show_ip=$(conf_get_value $new_folder/$COIN_CONFIG "externalip"     | cut -d : -f1)

	echo -e "===================================================================================================\
			\n${BLUE}$COIN_NAME${NC} duplicated masternode ${CYAN}number $1${NC} should be now up and trying to sync with the blockchain.\
			\nThe duplicated masternode uses the $([[ $show_ip ]] && echo "IP:PORT ${YELLOW}$show_ip:$([[ $mn_port ]] && echo $mn_port || echo ????)${NC}" || echo "same IP and PORT than the original one").\
			\nRPC port is ${MAGENTA}$NEW_RPC${NC}, this one is used to send commands to the wallet, DON'T put it in 'masternode.conf' (other programs might want to use this port which causes a conflict, but you can change it with ${MAGENTA}dupmn rpcchange $PROFILE_NAME $1 PORT_NUMBER${NC}).\
			\nStart:              ${RED}systemctl start   $COIN_NAME-$1.service${NC}\
			\nStop:               ${RED}systemctl stop    $COIN_NAME-$1.service${NC}\
			\nStart on reboot:    ${RED}systemctl enable  $COIN_NAME-$1.service${NC}\
			\nNo start on reboot: ${RED}systemctl disable $COIN_NAME-$1.service${NC}\
			\n(Currently configured to start on reboot)\
			\nDUPLICATED MASTERNODE PRIVATEKEY is: ${GREEN}$NEW_KEY${NC}\
			\nTo check the masternode status just use: ${GREEN}$COIN_CLI-$1 masternode status${NC} (Wait until the new masternode is synced with the blockchain before trying to start it).\
			\nNOTE 1: ${GREEN}$COIN_CLI-0${NC} and ${GREEN}$COIN_DAEMON-0${NC} are just a reference to the 'main masternode', not a created one with dupmn.\
			\nNOTE 2: You can use ${GREEN}$COIN_CLI-all [parameters]${NC} and ${GREEN}$COIN_DAEMON-all [parameters]${NC} to apply the parameters on all masternodes. Example: ${GREEN}$COIN_CLI-all masternode status${NC}\
			\n==================================================================================================="

	if [[ $IP ]]; then
		for (( i=0; i<$DUP_COUNT; i++ )); do
			if [[ $i != $1 && $(conf_get_value $(get_folder $i)$COIN_CONFIG "bind") == "$IP" ]]; then
				echo -e "${RED}WARNING:${NC} looks like that the ${BLUE}node $i${NC} already uses the same IP, it may cause that this dupe doesn't work"
				((retcode+=2))
				break;
			fi
		done
		if [[ ($IP_TYPE == 4 && ! $(get_ips 4 | grep -w $IP)) || ($IP_TYPE == 6 && ! $(get_ips 6 | grep -w ${IP:1:-1})) ]]; then
			echo -e "${RED}WARNING:${NC} IP ${GREEN}$IP${NC} is probably not added, the node may not work due to using a non-existent IP"
			((retcode+=4))
		fi
	fi

	echo_json "{\"message\":\"dupe successfully installed\",\"ip\":\"$([[ $show_ip ]] && echo $show_ip || echo null)\",\"port\":\"$([[ $mn_port ]] && echo $mn_port || echo null)\",\"rpc\":\"$NEW_RPC\",\"privkey\":\"$NEW_KEY\",\"dup\":$1,\"retcode\":$retcode}"
}
function cmd_reinstall() {
	# <$1 = instance_number>

	if [[ $FORCE_LISTEN == "1" && ! $IP ]]; then
		echo -e "${RED}ERROR:${NC} A profile with ${MAGENTA}FORCE_LISTEN=1${NC} requires a IP with -ip=IP extra parameter when reinstalling a dupe"
		echo_json "{\"error\":\"A profile with FORCE_LISTEN=1 requires a IP when reinstalling a dupe\",\"errcode\":17}" 
		return
	fi

	wallet_cmd stop $1 > /dev/null
	[[ ! $NEW_KEY ]] && NEW_KEY=$(conf_get_value $COIN_FOLDER$2/$COIN_CONFIG "masternodeprivkey")
	rm -rf $COIN_FOLDER$2

	cmd_install $1
	DUP_COUNT=$(($DUP_COUNT-1))

	$(make_chmod_file /usr/bin/$COIN_CLI-all    "#!/bin/bash\nfor (( i=0; i<=$DUP_COUNT; i++ )) do\n echo -e MN\$i:\n $COIN_CLI-\$i \$@\ndone")
	$(make_chmod_file /usr/bin/$COIN_DAEMON-all "#!/bin/bash\nfor (( i=0; i<=$DUP_COUNT; i++ )) do\n echo -e MN\$i:\n $COIN_DAEMON-\$i \$@\ndone")

	$(conf_set_value .dupmn/dupmn.conf $PROFILE_NAME $DUP_COUNT)
}
function cmd_uninstall() {
	# <$1* = instance_number/all>

	if [ $1 == "all" ]; then
		for (( i=$DUP_COUNT; i>=1; i-- )); do
			echo -e "Uninstalling ${BLUE}$PROFILE_NAME${NC} instance ${CYAN}number $i${NC}"
			wallet_cmd stop $i > /dev/null
			rm -rf /usr/bin/$COIN_CLI-$i
			rm -rf /usr/bin/$COIN_DAEMON-$i
			systemctl disable $COIN_NAME-$i.service &> /dev/null
			rm -rf /etc/systemd/system/$COIN_NAME-$i.service
			rm -rf $COIN_FOLDER$i
		done
		$(conf_set_value .dupmn/dupmn.conf $PROFILE_NAME 0 1)
		$(make_chmod_file /usr/bin/$COIN_CLI-all    "#!/bin/bash\nfor (( i=0; i<=0; i++ )) do\n echo -e MN\$i:\n $COIN_CLI-\$i \$@\ndone")
		$(make_chmod_file /usr/bin/$COIN_DAEMON-all "#!/bin/bash\nfor (( i=0; i<=0; i++ )) do\n echo -e MN\$i:\n $COIN_DAEMON-\$i \$@\ndone")
		systemctl daemon-reload
		echo_json "{\"message\":\"dupe/s successfully uninstalled\",\"count\":$DUP_COUNT,\"dupes\":[$(seq -s ',' 1 $DUP_COUNT)]}"
	else

		local del_list=($(echo $@ | xargs -n1 | sort -un | xargs))

		echo -e "Stopping ${BLUE}$PROFILE_NAME${NC} instances from ${CYAN}${del_list[0]}${NC} to ${CYAN}$DUP_COUNT${NC} for reorder after uninstall..."

		for (( i=${del_list[0]}; i<=$DUP_COUNT; i++ )); do
			wallet_cmd stop $i > /dev/null &
		done

		wait
		sleep 1

		for x in ${del_list[@]}; do
			echo -e "Removing ${BLUE}$PROFILE_NAME${NC} instance ${CYAN}$x${NC}"
			rm -rf $COIN_FOLDER$x
		done
		
		echo -e "Modifying instance pointers"

		for (( i=0; i < ${#del_list[@]}; i++ )); do
			rm -rf /usr/bin/$COIN_CLI-$(($DUP_COUNT-$i))
			rm -rf /usr/bin/$COIN_DAEMON-$(($DUP_COUNT-$i))
		done
		
		$(make_chmod_file /usr/bin/$COIN_CLI-all    "#!/bin/bash\nfor (( i=0; i<=$(($DUP_COUNT-${#del_list[@]})); i++ )) do\n echo -e MN\$i:\n $COIN_CLI-\$i \$@\ndone")
		$(make_chmod_file /usr/bin/$COIN_DAEMON-all "#!/bin/bash\nfor (( i=0; i<=$(($DUP_COUNT-${#del_list[@]})); i++ )) do\n echo -e MN\$i:\n $COIN_DAEMON-\$i \$@\ndone")
		$(conf_set_value .dupmn/dupmn.conf $PROFILE_NAME $(($DUP_COUNT-${#del_list[@]})) 1)

		local offset=${del_list[0]}
		local mv_list=($(seq -s ' ' $offset $DUP_COUNT))
		for x in ${del_list[@]}; do
			mv_list=( "${mv_list[@]/$x}" )
		done

		for x in ${mv_list[@]}; do
			echo -e "Setting ${CYAN}instance $x${NC} as ${CYAN}instance $offset${NC}"
			mv $COIN_FOLDER$x $COIN_FOLDER$offset
			wallet_cmd start $offset > /dev/null &
			offset=$(($offset+1))
		done

		echo -e "Starting all the renamed instances..."
		wait 

		echo -e "${BLUE}$PROFILE_NAME${NC} uninstalled instances: ${CYAN}${del_list[@]}${NC}"

		systemctl disable $COIN_NAME-$DUP_COUNT.service &> /dev/null
		rm -rf /etc/systemd/system/$COIN_NAME-$DUP_COUNT.service
		systemctl daemon-reload
		echo_json "{\"message\":\"dupe/s successfully uninstalled\",\"count\":${#del_list[@]},\"dupes\":[${del_list[@]}]}"
	fi
}
function cmd_bootstrap() {
	# <$1 = origin> | <$2 = destiny>

	local service_1=$([[ $1 -gt 0 ]] && echo "$COIN_NAME-$1.service" || echo "$COIN_SERVICE")
	local service_2=$([[ $2 -gt 0 ]] && echo "$COIN_NAME-$2.service" || echo "$COIN_SERVICE")

	if [[ $1 -eq $2 ]]; then
		echo "You cannot use the same node for the chain copy... that doesn't makes sense"
		echo_json "{\"error\":\"Cannot use the same node for the bootstrap\",\"errcode\":600}"
		return
	elif [[ ($1 -eq 0 || $2 -eq 0) && $(wallet_cmd loaded) ]]; then 
		if [[ ! $COIN_SERVICE || ! -f /etc/systemd/system/$COIN_SERVICE ]]; then
			[[ ! $COIN_SERVICE ]] && echo -e "${MAGENTA}Main MN service not detected in the profile, can't temporary stop the main node to copy the chain.${NC}" || echo -e "${MAGENTA}Main MN service ($COIN_SERVICE) not found in /etc/systemd/system${NC}"			
			echo -e "Main masternode must be stopped to copy the chain, use ${GREEN}$COIN_CLI stop${NC} to stop the main node."
			[[ $2 -eq 0 ]] && echo -e "Optionally you can put use a dupe as source of the chain files, example: ${YELLOW}dupmn bootstrap PROFILE 2 1${NC} (copy dupe 1 to dupe 2)."
			echo -e "NOTE: Some main nodes may need to stop a systemd service instead, like ${GREEN}systemctl stop $COIN_NAME.service${NC}."
			echo_json "{\"error\":\"Main node must be manually stopped for the bootstrap\",\"errcode\":601}"
			return
		fi
	fi

	local orig_loaded=$(wallet_cmd stop $1)
	local dest_loaded=$(wallet_cmd stop $2)

	echo -e "Copying stored chain from node $1 to $2... (may take a while)"
	for x in $(ls $(get_folder $2) | grep -v ".conf\|wallet.dat"); do
		rm -rf $(get_folder $2)$x
	done
	rsync -adm --ignore-existing --info=progress2 $(get_folder $1) $(get_folder $2)

	[[ $orig_loaded ]] && echo -e "Reactivating node $1..." && wallet_cmd start $1 > /dev/null
	[[ $dest_loaded ]] && echo -e "Reactivating node $2..." && wallet_cmd start $2 > /dev/null

	echo_json "{\"message\":\"Bootstrap applied\",\"origin\":{\"node\":$1,\"reenabled\":$(json_bool $orig_loaded)},\"destiny\":{\"node\":$2,\"reenabled\":$(json_bool $dest_loaded)}}"
}
function cmd_iplist() {
	local ipjs=()
	for iface in $(ls /sys/class/net | grep -v "lo"); do
		echo -e "Interface ${GREEN}$iface${NC}:"
		for ip in $(get_ips 4 1 $iface); do
			echo -e "  ${YELLOW}$ip${NC}"
			ipjs+=("{\"iface\":\"$iface\",\"ip\":\"$(echo $ip | cut -d / -f1)\",\"netmask\":$(echo $ip | cut -d / -f2),\"type\":4}")
		done
		for ip in $(get_ips 6 1 $iface); do
			echo -e "  ${CYAN}$ip${NC}"
			ipjs+=("{\"iface\":\"$iface\",\"ip\":\"$(echo $ip | cut -d / -f1)\",\"netmask\":$(echo $ip | cut -d / -f2),\"type\":6}")
		done
	done
	echo_json "{\"list\":[$(array_join , ${ipjs[@]})]}"
}
function cmd_ipmod() {
	# <$1 = add|del> | <$2 = ip> | <$3 = netmask> | [$4 = interface]

	local netmask=$(netmask_cidr $3)
	local iface=$([[ $4 ]] && echo $4 || ls /sys/class/net | grep -v "lo")

	if [[ ! $netmask ]]; then
		echo -e "${RED}ERROR:${NC} ${GREEN}$3${NC} hasn't a proper netmask structure"
		echo_json "{\"error\":\"Bad netmask structure\",\"errcode\":700}"
		return
	elif [[ $netmask -lt 0 || $netmask -gt $([[ $IP_TYPE == 4 ]] && echo 32 || echo 128) ]]; then
		echo -e "${RED}ERROR:${NC} Netmask must be a value between 0 and $([[ $IP_TYPE == 4 ]] && echo 32 || echo 128)"
		echo_json "{\"error\":\"Netmask out of range\",\"errcode\":701}"
		return
	elif [[ $4 && ! $(ls /sys/class/net | grep -v "lo" | grep "^$4$") ]]; then
		echo -e "${RED}ERROR:${NC} Interface ${GREEN}$4${NC} doesn't exists, use ${YELLOW}dupmn iplist${NC} to see the existing interfaces"
		echo_json "{\"error\":\"Interface doesn't exists\",\"errcode\":702}"
		return
	elif [[ $(echo "$iface" | wc -l) -gt 1 ]]; then
		echo -e "${RED}ERROR:${NC} There are 2 or more available interfaces, you'll have to specify it as an extra parameter, use ${YELLOW}dupmn iplist${NC} to see the existing interfaces"
		echo_json "{\"error\":\"Interface must be specified\",\"errcode\":703}"
		return
	fi

	if [[ $IP_TYPE == 6 && $(conf_get_value /etc/sysctl.conf net.ipv6.conf.all.disable_ipv6) == "1" ]]; then
		echo -e "IPv6 addresses are currently disabled, applying a change on ${MAGENTA}/etc/sysctl.conf${NC} to enable them"
		conf_set_value /etc/sysctl.conf net.ipv6.conf.all.disable_ipv6 0
		sysctl -p
	fi
	if [[ $1 == "add" && $(get_ips $IP_TYPE 0 $iface | grep "^$IP$") ]]; then
		echo -e "${RED}ERROR:${NC} IP ${CYAN}$2${NC} already exists in the interface ${GREEN}$iface${NC}"
		echo_json "{\"error\":\"IP already exists\",\"errcode\":704}"
		return
	elif [[ $1 == "del" && ! $(get_ips $IP_TYPE 0 $iface | grep "^$IP$") ]]; then
		echo -e "${RED}ERROR:${NC} IP ${CYAN}$2${NC} doesn't exists in the interface ${GREEN}$iface${NC}"
		echo_json "{\"error\":\"IP doesn't exists\",\"errcode\":704}"
		return
	fi

	local ip_res=$(ip -$IP_TYPE addr $1 $2/$netmask dev $iface 2>&1)
	if [[ ! $ip_res ]]; then
		touch /etc/init.d/dupmn_ipmanage
		local initd=$(cat /etc/init.d/dupmn_ipmanage | grep "^ip")
		if [[ $1 == "add" ]]; then
			initd+="\nip -$IP_TYPE addr add $IP/$netmask dev $iface"
		else
			initd=$(echo "$initd" | grep -v "ip -$IP_TYPE addr add $IP/$netmask dev $iface")
		fi
		echo -e "#!/bin/sh -e\
		\n### BEGIN INIT INFO\
		\n# Provides:          dupmn_ipmanage\
		\n# Required-Start:    \$remote_fs \$syslog\
		\n# Required-Stop:     \$remote_fs \$syslog\
		\n# Default-Start:     5\
		\n# Default-Stop:\
		\n# Short-Description: Start ips at boot time\
		\n# Description:       dupmn script ip manager to keep ips enabled after reboot\
		\n### END INIT INFO\
		\n\
		\n$initd\
		\n\
		\nexit 0" > /etc/init.d/dupmn_ipmanage
		chmod +x /etc/init.d/dupmn_ipmanage
		update-rc.d dupmn_ipmanage defaults
		echo -e "IP ${CYAN}$2${NC}/${YELLOW}$netmask${NC} successfully $([[ $1 == "add" ]] && echo "added" || echo "deleted")" 
	else
		echo -e "${RED}UNEXPECTED ERROR:${NC} $ip_res"
		echo_json "{\"error\":\"Unexpected error: $ip_res\",\"errcode\":705}"
	fi
	echo_json "{\"message\":\"IP $([[ $1 == "add" ]] && echo "added" || echo "deleted")\",\"ip\":\"$IP\",\"ip_type\":$IP_TYPE,\"iface\":\"$iface\"}"
}
function cmd_rpcchange() {
	# <$1 = instance_number> | [$2 = port_number]

	local new_port=$(stoi $(conf_get_value $(get_folder $1)/$COIN_CONFIG "rpcport"))

	if [[ ! $2 ]]; then
		echo -e "No port provided, the rpc port will be changed for any other free port..."
		new_port=$(find_port $new_port)
	elif [[ ! $(is_number $2) ]]; then
		echo -e "${CYAN}$2${NC} is not a number"
		echo_json "{\"error\":\"$2 is not a number\",\"errcode\":800}"
		return
	elif [[ $2 -lt 1024 || $2 -gt 49151 ]]; then
		echo -e "${MAGENTA}$2${NC} is not a valid or a reserved port (must be between ${MAGENTA}1024${NC} and ${MAGENTA}49151${NC})"
		echo_json "{\"error\":\"Port number reserved or out of range\",\"errcode\":801}"
		return
	else
		new_port=$(stoi $2)
		if [[ ! $(port_check $new_port) ]]; then
			echo -e "Port ${MAGENTA}$new_port${NC} seems to be in use by another process"
			echo_json "{\"error\":\"Port number already in use\",\"errcode\":802}"
			return
		fi
	fi

	if [[ $1 -eq 0 && (! $COIN_SERVICE || ! -f /etc/systemd/system/$COIN_SERVICE) && $(wallet_cmd loaded) ]]; then
		echo -e "The ${BLUE}$PROFILE_NAME${NC} main node must be manually stopped to change the rpc port"
		echo_json "{\"message\":\"Port changed, main node restart required\",\"port\":$new_port,\"retcode\":1}"
	else
		local wallet_loaded=$(wallet_cmd stop $1)
		$(conf_set_value $(get_folder $1)/$COIN_CONFIG "rpcport" $new_port 1)
		[[ $wallet_loaded ]] && wallet_cmd start $1 > /dev/null
		echo -e "${BLUE}$PROFILE_NAME${NC} node ${CYAN}number $1${NC} is now listening the rpc port ${MAGENTA}$new_port${NC}"
		echo_json "{\"message\":\"Port changed\",\"port\":$new_port,\"retcode\":0/}"
	fi
}
function cmd_systemctlall() {
	# <$1 = command>

	trap '' 2
	if [[ $COIN_SERVICE ]]; then
		if [[ -f /etc/systemd/system/$COIN_SERVICE ]]; then
			echo -e "${CYAN}systemctl $1 $COIN_SERVICE${NC}"
			systemctl $1 $COIN_SERVICE
		else
			echo -e "${MAGENTA}Main MN service ($COIN_SERVICE) not found in /etc/systemd/system${NC}"
		fi
	else
		echo -e "${MAGENTA}Main MN service not detected in the profile, applying command to dupes only${NC}"
	fi
	for (( i=1; i<=$DUP_COUNT; i++ )); do
		echo -e "${CYAN}systemctl $1 $COIN_NAME-$i.service${NC}"
		systemctl $1 $COIN_NAME-$i.service
	done
	trap 2
	echo_json "{\"message\":\"success\"}"
}
function cmd_list() {
	# [$1* = profile_name]

	function print_param_info() {
		# <$1 = json_key> | <$2 = value_quotes> | <$3 = str> | <$4 = strval>
		echo -e "$3$4"
		local json_val=$(echo "$4" | sed 's/\\e\[[0-9;]*m//g')
		js_params+=("\"$1\":$([[ $json_val ]] && echo $([[ $2 == 1 ]] && echo "\"$json_val\"" || echo "$json_val") || echo null)")
	}

	function print_dup_info() {
		# [$1 = dupe]
		local js_params=("\"id\":$([[ $1 ]] && echo $1 || echo 0)")
		local mn_status="$(try_cmd $(exec_coin cli $1) "masternodedebug" "masternode debug")"
		[[ ${args[@]} =~ "o" ]] && print_param_info "online"  0 "  online  : " "$([[ $mn_status ]] && echo ${BLUE}true${NC} || echo ${RED}false${NC})"
		[[ ${args[@]} =~ "b" ]] && print_param_info "block"   0 "  block   : " "$($(exec_coin cli $1) getblockcount)"
		[[ ${args[@]} =~ "s" ]] && print_param_info "status"  1 "  status  : " "$([[ $mn_status ]] && echo ${GRAY}${mn_status//[$'\r\n']}${NC} || echo ${RED}\(disabled\)${NC})"
		[[ ${args[@]} =~ "i" ]] && print_param_info "ip"      1 "  ip      : " "${YELLOW}$(conf_get_value $COIN_FOLDER$1/$COIN_CONFIG $([[ $(conf_get_value $COIN_FOLDER$1/$COIN_CONFIG "masternodeaddr") ]] && echo "masternodeaddr" || echo "externalip"))${NC}"
		[[ ${args[@]} =~ "r" ]] && print_param_info "rpcport" 0 "  rpcport : " "${MAGENTA}$(conf_get_value $COIN_FOLDER$1/$COIN_CONFIG rpcport)${NC}"
		[[ ${args[@]} =~ "p" ]] && print_param_info "privkey" 1 "  privkey : " "${GREEN}$(conf_get_value $COIN_FOLDER$1/$COIN_CONFIG masternodeprivkey)${NC}"
		js_dupes+=("{$(array_join , "${js_params[@]}")}")
	}

	local -A conf=$(get_conf .dupmn/dupmn.conf)
	local js_profs=()

	if [ ${#conf[@]} -eq 0 ]; then
		echo -e "(no profiles added)"
		echo_json "{\"profs\":[]}"
		return
	fi

	if [[ ! $1 ]]; then
		for var in "${!conf[@]}"; do
			echo -e "${CYAN}$var${NC} : ${conf[$var]}"
			js_profs+=("{\"name\":\"$var\",\"count\":${conf[$var]}}")
		done
		echo -e "Total count : $(echo ${conf[@]} | tr ' ' '\n' | cut -d '=' -f2 | awk '{ SUM += $1 } END { print SUM }') dupes (+ $(echo ${#conf[@]}) main nodes)"
		echo_json "{\"profs\":[$(array_join "," ${js_profs[@]})]}"
	else
		local args=()
		local params=$(echo "$@" | tr ' ' '\n' | grep '^-' | sed 's/^-//g')
		params+=" $(echo "$params" | grep -v '^-' | grep -o '.')"

		for param in $params; do
			case "$param" in
				"a"|"-all")
					args=(o b s i r p)
					break
					;;
				"o"|"-online")     args+=(o) ;;
				"b"|"-blockcount") args+=(b) ;;
				"s"|"-status")     args+=(s) ;;
				"i"|"-ip")         args+=(i) ;;
				"r"|"-rpcport")    args+=(r) ;;
				"p"|"-privkey")    args+=(p) ;;
			esac
		done

		local profs=$(echo "$@" | tr ' ' '\n' | sed '/^-/d')
		[[ ! $profs ]] && profs="${!conf[@]}"
		[[ ${#args[@]} -eq 0 ]] && args=(s i r p)

		for prof in $profs; do
			local check_prof=$(load_profile $prof 1 3> /dev/null)
			if [[ $check_prof ]]; then
				echo -e "$check_prof"
				js_profs+=("{\"name\":\"$prof\",\"err\":\"$check_prof\"}")
			else
				load_profile $prof 1
				local js_dupes=()
				echo -e "${BLUE}$prof${NC}: ${CYAN}$DUP_COUNT${NC} created nodes with dupmn"
				echo -e "${DARKCYAN}Main Node:${NC}"
				print_dup_info
				for (( i=1; i<=$DUP_COUNT; i++ )); do
					echo -e "${DARKCYAN}MN$i:${NC}"
					print_dup_info $i
				done
				js_profs+=("{\"name\":\"$prof\",\"count\":$DUP_COUNT,\"mn\":[$(array_join , "${js_dupes[@]}")]}")
			fi
			[[ $(echo "$profs" | grep -o ' ' | wc -l) -gt 1 ]] && echo -e ""
		done
		echo_json "{\"profs\":[$(array_join , "${js_profs[@]}")]}"
	fi
}
function cmd_swapfile() {
	# <$1 = size_in_mbytes>

	if [[ ! $(is_number $1) ]]; then
		echo -e "${YELLOW}<size_in_mbytes>${NC} must be a number"
		echo_json "{\"error\":\"<size_in_mbytes> must be a number\",\"errcode\":900}"
		return
	fi

	local avail_mb=$(df / --output=avail -m | grep [0-9])
	local total_mb=$(df / --output=size -m | grep [0-9])

	if [[ $1 -ge $avail_mb ]]; then
		echo -e "There's only $avail_mb MB available in the hard disk"
		echo_json "{\"error\":\"not enough available space: $avail_mb MB\",\"errcode\":901}"
		return
	fi

	[[ -f /mnt/dupmn_swapfile ]] && swapoff /mnt/dupmn_swapfile &> /dev/null

	if [[ $1 -eq 0 ]]; then
		rm -rf /mnt/dupmn_swapfile
		sed -i "/\/mnt\/dupmn_swapfile/d" /etc/fstab
		echo -e "Swapfile deleted"
		echo_json "{\"message\":\"swapfile deleted\"}"
	else
		echo -e "Generating swapfile, this may take some time depending on the size..."
		echo -e "$(($1 * 1024 * 1024)) bytes swapfile"
		dd if=/dev/zero of=/mnt/dupmn_swapfile bs=1024 bs=1M count=$1 status=progress
		chmod 600 /mnt/dupmn_swapfile &> /dev/null
		mkswap /mnt/dupmn_swapfile &> /dev/null
		swapon /mnt/dupmn_swapfile &> /dev/null
		/mnt/dupmn_swapfile swap swap defaults 0 0 &> /dev/null
		[[ ! $(cat /etc/fstab | grep "/mnt/dupmn_swapfile") ]] && echo "/mnt/dupmn_swapfile none swap 0 0" >> /etc/fstab
		echo -e "Swapfile new size = ${GREEN}$1 MB${NC}"
		echo_json "{\"message\":\"swapfile created\"}"
	fi

	echo -e "Use ${YELLOW}swapon -s${NC} to see the changes of your swapfile and ${YELLOW}free -m${NC} to see the total available memory"
}
function cmd_checkmem() {
	local checks=$(ps -o %mem,command ax | awk '$1 >= 0.1 && $2 ~ /.d$/ && $3 == "-daemon" { print $2 " " $1 }' | sed 's@.*/@@')
	local daemons=$(echo "$checks" | awk '{ print $1 }' | sort -u)
	output=()

	for x in $daemons; do # ( "name count usage", ... )
		output+=( "$x $(echo "$checks" | grep -c "$x") $(echo "$checks" | grep "$x" | awk '{ SUM += $2 } END { print SUM }')" )
	done

	local npadd=$(echo "$daemons" | wc -L)
	local zpadd=$(($(echo "$output" | awk '{ print $2 }' | wc -L) + 1))
	for x in "${output[@]}"; do
		printf "%-$((npadd))s $(seq -s " " $((zpadd - $(echo $x | awk '{ print $2 }' | wc -L))) | tr -d "[0-9]")(%s) : %s %%\n" $x
	done

	echo "$checks" | awk '{ SUM += $2 } END { print "Total mem. usage : "SUM" %" }'
	echo_json "{\"daemons\":[$(array_join , $(printf "%s\n" "${output[@]}" | awk '{ print "{\"name\":\"" $1 "\",\"count\":" $2 ",\"mem\":" $3 "}" }'))],\"total_mem\":$(echo "$checks" | awk '{ SUM += $2 } END { print SUM }')}"
}
function cmd_help() {
	echo -e "Options:\
			\n  - ${YELLOW}dupmn profadd <prof_file> [prof_name]          ${NC}Adds a profile that will be used to create duplicates of the masternode, it will use the COIN_NAME parameter as name if a prof_name is not provided.\
			\n  - ${YELLOW}dupmn profdel <prof_name>                      ${NC}Deletes the given profile name, this will uninstall too any dupe that uses this profile.\
			\n  - ${YELLOW}dupmn install <prof_name> [params...]          ${NC}Install a new dupe based on the parameters of the given profile name.\
			\n      ${YELLOW}[params...]${NC} list:\
			\n        ${GREEN}-i ${DARKCYAN}IP${NC},  ${GREEN}--ip=${DARKCYAN}IP${NC}       Use a specific IPv4 or IPv6.\
			\n        ${GREEN}-r ${DARKCYAN}RPC${NC}, ${GREEN}--rpcport=${DARKCYAN}RPC${NC} Use a specific port for RPC commands (must be valid and not in use).\
			\n        ${GREEN}-p ${DARKCYAN}KEY${NC}, ${GREEN}--privkey=${DARKCYAN}KEY${NC} Set a user-defined masternode private key.\
			\n        ${GREEN}-b${NC},     ${GREEN}--bootstrap${NC}   Apply a bootstrap during the installation.\
			\n  - ${YELLOW}dupmn reinstall <prof_name> <node> [params...] ${NC}Reinstalls the specified dupe, this is just in case if the dupe is giving problems.\
			\n      ${YELLOW}[params...]${NC} list:\
			\n        ${GREEN}-i ${DARKCYAN}IP${NC},  ${GREEN}--ip=${DARKCYAN}IP${NC}       Use a specific IPv4 or IPv6.\
			\n        ${GREEN}-r ${DARKCYAN}RPC${NC}, ${GREEN}--rpcport=${DARKCYAN}RPC${NC} Use a specific port for RPC commands (must be valid and not in use).\
			\n        ${GREEN}-p ${DARKCYAN}KEY${NC}, ${GREEN}--privkey=${DARKCYAN}KEY${NC} Set a user-defined masternode private key.\
			\n        ${GREEN}-b${NC},     ${GREEN}--bootstrap${NC}   Apply a bootstrap during the reinstallation.\
			\n  - ${YELLOW}dupmn uninstall <prof_name> <node...|all>      ${NC}Uninstall the specified node/s of the given profile name, you can put ${YELLOW}all${NC} instead of a node number/s to uninstall all the duplicated instances.\
			\n  - ${YELLOW}dupmn bootstrap <prof_name> <node_1> <node_2>  ${NC}Copies the chain from node_1 to node_2.\
			\n  - ${YELLOW}dupmn iplist                                   ${NC}Shows all your configurated IPv4 and IPv6.\
			\n  - ${YELLOW}dupmn ipadd <ip> <netmask> [interface]         ${NC}Allows the system to recognize a new IPv4 or IPv6.\
			\n  - ${YELLOW}dupmn ipdel <ip> <netmask> [interface]         ${NC}Deletes an already recognized IPv4 or IPv6.\
			\n  - ${YELLOW}dupmn rpcchange <prof_name> <node> [port]      ${NC}Changes the RPC port used from the given node with the new one (or finds a new one by itself if no port is given).\
			\n  - ${YELLOW}dupmn systemctlall <prof_name> <command>       ${NC}Applies the systemctl command to all the duplicated instances of the given profile name.\
			\n  - ${YELLOW}dupmn list [prof_names...] [params...]         ${NC}Shows the amount of duplicated instances of every masternode, if a profile name/s are provided, it lists an extended info of the profile/s instances.\
			\n      ${YELLOW}[params...]${NC} list:\
			\n        ${GREEN}-a${NC}, ${GREEN}--all${NC}             Use all the available params below.\
			\n        ${GREEN}-o${NC}, ${GREEN}--online${NC}          Show if the node is active or not.\
			\n        ${GREEN}-b${NC}, ${GREEN}--blockcount${NC}      Show the current block number.\
			\n        ${GREEN}-s${NC}, ${GREEN}--status${NC}          Show the masternode status message.\
			\n        ${GREEN}-i${NC}, ${GREEN}--ip${NC}              Show the ip and port.\
			\n        ${GREEN}-r${NC}, ${GREEN}--rpcport${NC}         Show the rpc port.\
			\n        ${GREEN}-p${NC}, ${GREEN}--privkey${NC}         Show the masternode private key.\
			\n  - ${YELLOW}dupmn checkmem                                 ${NC}Shows the memory usage (%) of every group of nodes.\
			\n  - ${YELLOW}dupmn swapfile <size_in_mbytes>                ${NC}Creates, changes or deletes (if parameter is ${CYAN}0${NC}) a swapfile of the given size in MB to increase the virtual memory.\
			\n  - ${YELLOW}dupmn update                                   ${NC}Checks the last version of the script and updates it if necessary.\
			\n**NOTE 1**: ${YELLOW}<parameter>${NC} means required, ${YELLOW}[parameter]${NC} means optional, ${YELLOW}node${NC} is always a number that refers to a dupe (${CYAN}0${NC} is the main node).\
			\n**NOTE 2**: Check ${CYAN}https://github.com/neo3587/dupmn/wiki/Commands${NC} for extended info and usage examples of each command.\
			\n**NOTE 3**: Check ${CYAN}https://github.com/neo3587/dupmn/wiki/FAQs${NC} for technical questions and troubleshooting."
}
function cmd_update() {
	curl -sL https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn_install.sh 3>&3 | bash
	exit
}


function main() {

	function instance_valid() {
		# <$1 = instance_number> | [$2 = allow number 0]

		if [[ ! $(is_number $1) ]]; then
			echo -e "${RED}$1${NC} is not a number"
			echo_json "{\"error\":\"not a number: $1\",\"errcode\":200}"
			exit
		elif [[ $1 -eq 0 && $2 -ne 1 ]]; then
			echo -e "Instance ${CYAN}0${NC} is a reference to the main node, not a dupe, can't use this one in this command"
			echo_json "{\"error\":\"main node reference not allowed\",\"errcode\":201}"
			exit
		elif [[ $1 -gt $DUP_COUNT ]]; then
			echo -e "Instance ${CYAN}$(stoi $1)${NC} doesn't exists, there are only ${CYAN}$DUP_COUNT${NC} instances of ${BLUE}$PROFILE_NAME${NC}"
			echo_json "{\"error\":\"not existing dupe\",\"errcode\":202}"
			exit
		fi
	}
	function ip_parse() {
		# <$1 = IPv4 or IPv6> | [$2 = IPv6 brackets]

		IP=$1

		local ipv4_regex="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
		local ipv6_regex=(
				"^([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}$|"
				"^([0-9a-fA-F]{1,4}:){1,7}:$|"
				"^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$|"
				"^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$|"
				"^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$|"
				"^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$|"
				"^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$|"
				"^[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})$|"
				"^:((:[0-9a-fA-F]{1,4}){1,7}|:)$"
		)

		if [[ "$1" =~ $ipv4_regex ]]; then
			IP_TYPE=4
			return
		elif [[ "$1" =~ $(printf "%s" "${ipv6_regex[@]}") ]]; then

			[[ $(echo $IP | grep "^:") ]] && IP="0${IP}"

			if [[ $(echo $IP | grep "::") ]]; then
				IP=$(echo $IP | sed "s/::/$(echo ":::::::::" | sed "s/$(echo $IP | sed 's/[^:]//g')//" | sed 's/:/:0/g')/")
			fi

			IP=$(echo $IP | grep -o "[0-9a-f]\+" | sed "s/^/0x/" | xargs printf "%x\n" | paste -sd ":" | sed "s/:0:/::/")

			while [[ "$IP" =~ "::0:" ]]; do
				IP=$(echo $IP | sed 's/::0:/::/g')
			done
			while [[ "$IP" =~ ":::" ]]; do
				IP=$(echo $IP | sed 's/:::/::/g')
			done

			[[ "$2" == "1" ]] && IP="[$IP]"
			IP_TYPE=6
			return
		fi

		echo -e "${GREEN}$1${NC} doesn't have the structure of a IPv4 or a IPv6"
		echo_json "{\"error\":\"not a IP: $1\",\"errcode\":300}"
		exit
	}
	function opt_install_params() {
		function extract_param() {
			# <$1* = args>
			[[ "${!i}" =~ ^-[a-z]$ ]] && ((i++)) && echo ${!i} || echo ${!i:$(echo ${!i} | cut -d '=' -f1 |  wc -c)}
		}
		for (( i=1; i<=$#; i++ )); do
			case "${!i}" in
				"-i"|--ip=*)
					ip_parse "$(extract_param $@)" "1"
					;;
				"-r"|--rpcport=*)
					NEW_RPC="$(extract_param $@)"
					[[ $NEW_RPC -lt 1024 ||  $NEW_RPC -gt 49151 ]] && echo "-rpcport must be between 1024 and 49451" && exit
					[[ ! $(port_check $NEW_RPC) ]] && echo "given -rpcport seems to be in use" && exit
					;;
				"-p"|--privkey=*)
					NEW_KEY="$(extract_param $@)"
					;;
				"-b"|--bootstrap)
					INSTALL_BOOTSTRAP="1"
					;;
			esac
		done
	}
	function exit_no_param() {
		# <$1 = param> | <$2 = message>
		if [[ ! $1 ]]; then
			echo -e "$2"
			echo_json "{\"error\":\"$(echo "$2" | sed 's/\\e\[[0-9;]*m//g')\",\"errcode\":3}"
			exit
		fi
	}

	if [[ ! $1 ]]; then
		echo -e "No command inserted, use ${YELLOW}dupmn help${NC} to see all the available commands"
		echo_json "{\"error\":\"no command inserted\",\"errcode\":1}"
		return
	fi

	local curr_dir=$PWD
	cd ~

	case "$1" in
		"profadd")
			exit_no_param "$2" "${YELLOW}dupmn profadd <prof_file> [prof_name]${NC} requires a profile file and optionally a new profile name as parameters"
			cd $curr_dir
			cmd_profadd $2 $3
			;;
		"profdel")
			exit_no_param "$2" "${YELLOW}dupmn profadd <prof_name>${NC} requires a profile name as parameter"
			load_profile $2
			cmd_profdel
			;;
		"install")
			exit_no_param "$2" "${YELLOW}dupmn install <prof_name> [params...]${NC} requires a profile name of an added profile as a parameter"
			load_profile $2 1
			opt_install_params "${@:3}"
			cmd_install $(($DUP_COUNT+1))
			;;
		"reinstall")
			exit_no_param "$3" "${YELLOW}dupmn reinstall <prof_name> <node> [params...]${NC} requires a profile name and a node number as parameters"
			load_profile $2 1
			instance_valid $3
			opt_install_params "${@:4}"
			cmd_reinstall $(stoi $3)
			;;
		"uninstall")
			exit_no_param "$3" "${YELLOW}dupmn uninstall <prof_name> <node...|all>${NC} requires a profile name and a node number/s (or all) as parameters"
			load_profile $2
			[[ ! ${@:3} =~ "all" ]] && for arg in ${@:3}; do instance_valid $arg; done
			cmd_uninstall $([[ ${@:3} =~ "all" ]] && echo "all" || echo $(for x in ${@:3}; do echo $(stoi $x); done))
			;;
		"bootstrap")
			exit_no_param "$4" "${YELLOW}dupmn bootstrap <prof_name> <node_1> <node_2>${NC} requires a profile name and 2 node numbers as parameters"
			load_profile $2 1
			instance_valid $3 1
			instance_valid $4 1
			cmd_bootstrap $(stoi $3) $(stoi $4)
			;;
		"iplist")
			cmd_iplist
			;;
		"ipadd")
			exit_no_param "$3" "${YELLOW}dupmn ipadd <ip> <netmask> [interface]${NC} requires a IP, a netmask and a interface name (if there's more than 1)"
			ip_parse $2
			cmd_ipmod "add" $2 $3 $4
			;;
		"ipdel")
			exit_no_param "$3" "${YELLOW}dupmn ipdel <ip> <netmask> [interface]${NC} requires a IP, a netmask and a interface name (if there's more than 1)"
			ip_parse $2
			cmd_ipmod "del" $2 $3 $4
			;;
		"rpcchange")
			exit_no_param "$3" "${YELLOW}dupmn rpcchange <prof_name> <node> [port]${NC} requires a profile name, node number and optionally a port number as parameters"
			load_profile $2 1
			instance_valid $3 1
			cmd_rpcchange $(stoi $3) $4
			;;
		"systemctlall")
			exit_no_param "$3" "${YELLOW}dupmn systemctlall <prof_name> <command>${NC} requires a profile name and a command as parameters"
			load_profile $2
			cmd_systemctlall $3
			;;
		"list")
			cmd_list ${@:2}
			;;
		"swapfile")
			exit_no_param "$2" "${YELLOW}dupmn swapfile <size_in_mbytes>${NC} requires a number as parameter"
			cmd_swapfile $(stoi $2)
			;;
		"checkmem")
			cmd_checkmem
			;;
		"help")
			cmd_help
			;;
		"update")
			cmd_update
			;;
		*)
			echo -e "Unrecognized parameter: ${RED}$1${NC}"
			echo -e "use ${YELLOW}dupmn help${NC} to see all the available commands"
			echo_json "{\"error\":\"unknown command: $1\",\"errcode\":2}"
			;;
	esac
}

main $@
