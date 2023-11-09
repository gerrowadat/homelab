FROM python:3.8
RUN apt-get -y update
RUN apt-get install -y python3-pip
RUN pip3 install certbot certbot-dns-joker certbot-dns-google

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

USER root

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/entrypoint.sh"]
