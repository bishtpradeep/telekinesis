#! /bin/sh
gzip -c --best /var/log/system.log > /tmp/random.dat
openssl rand -rand file:random.dat 0
rm random.dat
openssl req  -config "$1" -keyout "$2" -newkey rsa:1024 -nodes -x509 -days 365 -out "$2"