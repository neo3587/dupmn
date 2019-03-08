#!/bin/bash

readonly GREEN='\e[1;32m'
readonly YELLOW='\e[1;33m'
readonly CYAN='\e[1;36m'
readonly NC='\e[0m'

echo -e "Checking needed dependencies..."
if [ ! "$(command -v lsof)" ]; then
	echo -e "Installing ${CYAN}lsof${NC}..."
	sudo apt-get install lsof
fi
if [ ! "$(command -v curl)" ]; then
	echo -e "Installing ${CYAN}curl${NC}..."
	sudo apt-get install curl
fi

dupmn_update=$(curl -s https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn.sh)

echo -e "\n===================================================\
		\n   ██████╗ ██╗   ██╗██████╗ ███╗   ███╗███╗   ██╗  \
		\n   ██╔══██╗██║   ██║██╔══██╗████╗ ████║████╗  ██║  \
		\n   ██║  ██║██║   ██║██████╔╝██╔████╔██║██╔██╗ ██║  \
		\n   ██║  ██║██║   ██║██╔═══╝ ██║╚██╔╝██║██║╚██╗██║  \
		\n   ██████╔╝╚██████╔╝██║     ██║ ╚═╝ ██║██║ ╚████║  \
		\n   ╚═════╝  ╚═════╝ ╚═╝     ╚═╝     ╚═╝╚═╝  ╚═══╝  \
		\n                                ╗ made by neo3587 ╔\
		\n           Source: ${CYAN}https://github.com/neo3587/dupmn${NC}\
		\n   FAQs: ${CYAN}https://github.com/neo3587/dupmn/wiki/FAQs${NC}\
		\n  BTC Donations: ${YELLOW}3F6J19DmD5jowwwQbE9zxXoguGPVR716a7${NC}\
		\n===================================================\
		\n                                                   "

if [[ -f /usr/bin/dupmn && ! $(diff -q <(cat <(echo "$dupmn_update")) <(cat /usr/bin/dupmn)) ]]; then
	echo -e "${GREEN}dupmn${NC} is already updated to the last version\n"
	exit
fi

if [ ! -d ~/.dupmn ]; then
	mkdir ~/.dupmn
fi
touch ~/.dupmn/dupmn.conf

update=$([[ -f /usr/bin/dupmn ]] && echo "1" || echo "0")

echo "$dupmn_update" > /usr/bin/dupmn
chmod +x /usr/bin/dupmn

if [[ $update = "1" ]]; then
	echo -e "${GREEN}dupmn${NC} updated to the last version, pretty fast, right?\n"
else
	echo -e "${GREEN}dupmn${NC} installed, pretty fast, right?\n"
fi
