#!/bin/bash

mv ./dupmn.sh /usr/bin/dupmn
chmod +x /usr/bin/dupmn
if [ ! -d ~/.dupmn ]; then
	mkdir ~/.dupmn
fi
touch ~/.dupmn/dupmn.conf
echo -e "dupmn installed, pretty fast, right?"
