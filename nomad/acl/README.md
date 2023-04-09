ACL configs.
============

backpack.sh will bootstrap the ACL policies you want for basic operations.

Additional stuff you want to do (You'll have to save the tokens to use them).

Generate a token that can read any variables:

```
nomad acl token create -name="variable reader/writer" -policy=variable-admin
```
