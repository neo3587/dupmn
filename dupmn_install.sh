#!/bin/bash

GREEN='\e[1;32m'
NC='\e[0m'

rm -rf ./dupmn.sh
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn.sh

echo -e "\n===================================================\
         \n   ██████╗ ██╗   ██╗██████╗ ███╗   ███╗███╗   ██╗  \
         \n   ██╔══██╗██║   ██║██╔══██╗████╗ ████║████╗  ██║  \
         \n   ██║  ██║██║   ██║██████╔╝██╔████╔██║██╔██╗ ██║  \
         \n   ██║  ██║██║   ██║██╔═══╝ ██║╚██╔╝██║██║╚██╗██║  \
         \n   ██████╔╝╚██████╔╝██║     ██║ ╚═╝ ██║██║ ╚████║  \
         \n   ╚═════╝  ╚═════╝ ╚═╝     ╚═╝     ╚═╝╚═╝  ╚═══╝  \
         \n                                ╗ made by neo3587 ╔\
         \n           Source: https://github.com/neo3587/dupmn\
         \n  BTC Donations: 3HE1kwgHEWvxBa38NHuQbQQrhNZ9wxjhe7\
         \n===================================================\
         \n                                                   "

if [[ -f /usr/bin/dupmn && ! $(diff -q ./dupmn.sh /usr/bin/dupmn) ]]; then
	echo -e "${GREEN}dupmn${NC} is already updated to the last version\n"
	rm -rf ./dupmn.sh
	exit
fi

if [ ! -d ~/.dupmn ]; then
	mkdir ~/.dupmn
fi
touch ~/.dupmn/dupmn.conf

update=$([[ -f /usr/bin/dupmn ]] && echo "1" || echo "0")

mv ./dupmn.sh /usr/bin/dupmn
chmod +x /usr/bin/dupmn

if [[ $update = "1" ]]; then
	echo -e "${GREEN}dupmn${NC} updated to the last version, pretty fast, right?\n"
else 
	echo -e "${GREEN}dupmn${NC} installed, pretty fast, right?\n"
fi
