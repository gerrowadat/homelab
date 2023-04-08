#!/bin/sh

nomad acl policy apply -description "Variable reader/writer" variable-admin variable-admin-policy.hcl
