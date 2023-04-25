#!/bin/bash

NOMAD_VAR_BASE=restic/

echo -n "Enter config name: "
read resticrunner_config_name

echo -n "Enter ssh keyfile name : "
read ssh_keyfile

if [ ! -f ${ssh_keyfile} ]
then
  echo "Cannot read keyfile ${ssh_keyfile}"
  exit
fi

echo -n "Enter restic repo name: "
read restic_repo_name

echo -n "Enter restic repo password: "
read restic_repo_pass

ssh_key=`cat ${ssh_keyfile}`

nomad var put -force -in hcl - <<EOF
path = "$NOMAD_VAR_BASE${resticrunner_config_name}"

items {
    repo = "${restic_repo_name}"
    repo_pass = "${restic_repo_pass}"
    ssh_key = <<EOKEY
${ssh_key}
EOKEY
}
EOF
