#!/bin/bash

if [ "$CONSUL_GOSSIP_KEY" == "" ]
then
  echo "Please set CONSUL_GOSSIP_KEY"
  exit
fi

ansible-playbook -i inventory.yml site.yml
