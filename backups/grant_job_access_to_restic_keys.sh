#!/bin/bash
#
# Standard disclaimer that you likely shouldn't do ths outside a homelab.

JOB=$1
CONFIG=$2

if [ "$JOB" == "" ] || [ "$CONFIG" == "" ]
then
  echo "Usage: $0 <nomad_job_name> <restic_config_name>"
  exit
fi

echo "reading restic/$CONFIG"

nomad var get restic/$CONFIG > /dev/null

if [ "$?" != 0 ]
then
  echo "Error verifying existence of restic/${CONFIG} nomad variable"
  exit
fi

echo "Checking nomad job: $JOB"

nomad job status $JOB > /dev/null

if [ "$?" != 0 ]
then
  echo "Error verifying existence of '$JOB'nomad job"
  exit
fi

POLICY_NAME="${JOB}-restic-${conf}-policy"
POLICY_NAME="${POLICY_NAME//_/-}"

nomad acl policy apply -namespace default -job $JOB $POLICY_NAME - <<EOF
namespace "default" {
  variables {
    path "restic/${CONFIG}" {
      capabilities = ["read", "list"]
    }
  }
}
EOF


if [ "$?" != 0 ]
then
  echo "Whoops."
  exit $?
fi

echo "Done."
