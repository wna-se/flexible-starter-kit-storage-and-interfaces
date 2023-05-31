#!/bin/bash

set -e -u

script_dir=$(dirname "$0")

out_dir=/shared/cert
mkdir -p -- "$out_dir" || exit

# List all certificates we want, so that we can check if they already exist.
server=( ca.crt server.{crt,key} )
client=( client.{crt,key} )
targets=( "${client[@]}" "${server[@]}" )

# Check if certificates exist.
echo 'Checking certificates'
recreate=false
for target in "${targets[@]}"; do
    target=$out_dir/$target

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
	-keyout "$out_dir/ca.key" \
	-new \
	-nodes \
	-out "$out_dir/ca.csr" \
	-sha256
openssl req \
	-config "$script_dir/ssl.cnf" \
	-days 7300 \
	-extensions v3_ca \
	-key "$out_dir/ca.key" \
	-new \
	-nodes \
	-out "$out_dir/ca.crt" \
	-sha256 \
	-x509

# Create certificate for servers.
openssl req \
	-config "$script_dir/ssl.cnf" \
	-extensions server_cert \
	-keyout "$out_dir/server.key" \
	-new \
	-newkey rsa:4096 \
	-nodes \
	-out "$out_dir/server.csr" 

openssl x509 \
	-CA "$out_dir/ca.crt" \
	-CAkey "$out_dir/ca.key" \
	-days 1200 \
	-extensions server_cert \
	-extfile "$script_dir/ssl.cnf" \
	-in "$out_dir/server.csr" \
	-out "$out_dir/server.crt" \
	-req \
	-set_serial 01

# Create certificate for clients.
openssl req \
	-config "$script_dir/ssl.cnf" \
	-extensions client_cert \
	-keyout "$out_dir/client.key" \
	-new \
	-newkey rsa:4096 \
	-nodes \
	-out "$out_dir/client.csr" \
	-subj "/CN=admin"

openssl x509 \
	-CA "$out_dir/ca.crt" \
	-CAkey "$out_dir/ca.key" \
	-days 1200 \
	-extensions client_cert \
	-extfile "$script_dir/ssl.cnf" \
	-in "$out_dir/client.csr" \
	-out "$out_dir/client.crt" \
	-req \
	-set_serial 01

# fix permissions
cp "$out_dir"/server.key "$out_dir"/mq.key
chown 0:101 "$out_dir"/mq.key
chmod 640 "$out_dir"/mq.key

cp "$out_dir"/server.key "$out_dir"/db.key
chown 0:70 "$out_dir"/db.key
chmod 640 "$out_dir"/db.key

cp "$out_dir"/server.key "$out_dir"/download.key
chown 0:65534 "$out_dir"/download.key
chmod 640 "$out_dir"/download.key

chown 0:65534 "$out_dir"/client.*
chmod 640 "$out_dir"/client.*
