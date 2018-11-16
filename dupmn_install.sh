#!/bin/bash

wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn.sh
mv ./dupmn.sh /usr/bin/dupmn
chmod +x /usr/bin/dupmn
if [ ! -d ~/.dupmn ]; then
	mkdir ~/.dupmn
fi
touch ~/.dupmn/dupmn.conf
echo -e "dupmn installed, pretty fast, right?"
