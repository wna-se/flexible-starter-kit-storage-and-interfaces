#!/bin/bash

set -e -u

script_dir=$(dirname "$0")

out_dir=/shared/cert
mkdir -p -- "$out_dir" || exit
cd -- "$out_dir" || exit

# Read the most recently used serial number, if available.
# Increment by one and store it for the next time.
if [ -f "$script_dir"/serial.txt ]; then
	read serial < "$script_dir"/serial.txt
	serial=$((serial + 1))
else
	serial=1
fi
printf '%d\n' "$serial" >"$script_dir"/serial.txt

# List all certificates we want, so that we can check if they already exist.
server=( ca.crt server.{crt,key} )
client=( client.{crt,key} )
targets=( "${client[@]}" "${server[@]}" )

# Check if certificates exist.
echo 'Checking certificates'
recreate=false
for target in "${targets[@]}"; do
    if [ ! -f "$target" ]; then
	printf '"%s" is missing\n' "$target"
        recreate=true
        break
    fi
done

# Only recreate certificates if any certificate is missing.
if ! "$recreate"; then
    echo 'Certificates already exists'
    exit
fi

# Create CA certificate.
openssl req \
	-config "$script_dir/ssl.cnf" \
	-extensions v3_ca \
	-keyout ca.key \
	-new \
	-nodes \
	-out ca.csr \
	-sha256
openssl req \
	-config "$script_dir/ssl.cnf" \
	-days 7300 \
	-extensions v3_ca \
	-key ca.key \
	-new \
	-nodes \
	-out ca.crt \
	-sha256 \
	-x509

# Create certificate for servers.
openssl req \
	-config "$script_dir/ssl.cnf" \
	-extensions server_cert \
	-keyout server.key \
	-new \
	-newkey rsa:4096 \
	-nodes \
	-out server.csr 

openssl x509 \
	-CA ca.crt \
	-CAkey ca.key \
	-days 1200 \
	-extensions server_cert \
	-extfile "$script_dir/ssl.cnf" \
	-in server.csr \
	-out server.crt \
	-req \
	-set_serial "$serial"

# Create certificate for clients.
openssl req \
	-config "$script_dir/ssl.cnf" \
	-extensions client_cert \
	-keyout client.key \
	-new \
	-newkey rsa:4096 \
	-nodes \
	-out client.csr \
	-subj '/CN=admin'

openssl x509 \
	-CA ca.crt \
	-CAkey ca.key \
	-days 1200 \
	-extensions client_cert \
	-extfile "$script_dir/ssl.cnf" \
	-in client.csr \
	-out client.crt \
	-req \
	-set_serial "$serial"

# fix permissions
cp server.key mq.key
chown 0:101 mq.key
chmod 640 mq.key

cp server.key db.key
chown 0:70 db.key
chmod 640 db.key

cp server.key download.key
chown 0:65534 download.key
chmod 640 download.key

chown 0:65534 client.*
chmod 640 client.*
