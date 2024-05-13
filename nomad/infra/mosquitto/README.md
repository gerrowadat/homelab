mosquitto MQTT server
---------------------

This is mainly used by home assistant. It's a pretty standard setup, aside from getting its password file from a nomad var.

To set up your password file, generate a .htaccess file (on ubuntu, install `apache2-utils` and then `htpasswd -c mypasswdfile myuser`).

Then, load it into nomad:

```
go install github.com/gerrowadat/nomad-homelab/nomad-conf@latest
nomad-conf upload mypasswdfile nomad/job/mosquitto:passwd
```

nomad by default lets all tasks in a job access the `nomad/jobs/<jobname>` variable, so once your job is named 'mosquitto' you're all set.

If you need to update your passwd file, you'll need to run the above again - if you want to get your existing passwd file from nomad, it's `nomad-conf var get nomad/jobs/mosquitto:passwd` 
