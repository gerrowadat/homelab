#!/bin/bash

# This just creates dummy certs to load into nginx while configtesting.


openssl req -x509 -nodes -newkey rsa:2048 -days 9999 -keyout dummy-privkey.pem -out dummy-fullchain.pem -subj '/CN=localhost'
