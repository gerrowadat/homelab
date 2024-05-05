FROM ubuntu:latest

RUN apt update
RUN apt -y install nginx openssl

# Copy a dummy HAproxy upstreams file.
COPY local-haproxy-upstreams.conf /local/local-haproxy-upstreams.conf

# Generate dummy SSL certs.
RUN openssl req -x509 -nodes -newkey rsa:2048 -days 9999 -keyout /tmp/dummy-privkey.pem -out /tmp/dummy-fullchain.pem -subj '/CN=localhost'
RUN mkdir /secrets
RUN ln -s /tmp/dummy-privkey.pem /secrets/home.andvari.net-privkey.pem
RUN ln -s /tmp/dummy-privkey.pem /secrets/drone.home.andvari.net-privkey.pem
RUN ln -s /tmp/dummy-fullchain.pem /secrets/home.andvari.net-fullchain.pem
RUN ln -s /tmp/dummy-fullchain.pem /secrets/drone.home.andvari.net-fullchain.pem

# Generate dummy Diffie-Hellmann doodly doo.
RUN mkdir -p /etc/letsencrypt
RUN openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048

# Don't care about this.
RUN ln -s /dev/null /etc/letsencrypt/options-ssl-nginx.conf
