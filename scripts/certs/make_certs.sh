#!/bin/sh

set -e

out_dir="/shared/cert"

script_dir="$(dirname "$0")"
mkdir -p "$out_dir"

# list all certificates we want, so that we can check if they already exist
server="/shared/cert/ca.crt /shared/cert/server.crt /shared/cert/server.key"
client="/shared/cert/client.crt /shared/cert/client.key"
targets="$client $server"

echo ""
echo "Checking certificates"
recreate="false"
# check if certificates exist
for target in $targets; do
    if [ ! -f "$target" ]; then
        echo "$target is missing"
        recreate="true"
        break
    fi
done

# only recreate certificates if any certificate is missing
if [ "$recreate" = "false" ]; then
    echo "certificates already exists"
    exit 0
fi

# create CA certificate
openssl req -config "$script_dir/ssl.cnf" -new -sha256 -nodes -extensions v3_ca -out "$out_dir/ca.csr" -keyout "$out_dir/ca.key"
openssl req -config "$script_dir/ssl.cnf" -key "$out_dir/ca.key" -x509 -new -days 7300 -sha256 -nodes -extensions v3_ca -out "$out_dir/ca.crt"

# Create certificate for servers
openssl req -config "$script_dir/ssl.cnf" -new -nodes -newkey rsa:4096 -keyout "$out_dir/server.key" -out "$out_dir/server.csr" -extensions server_cert
openssl x509 -req -in "$out_dir/server.csr" -days 1200 -CA "$out_dir/ca.crt" -CAkey "$out_dir/ca.key" -set_serial 01 -out "$out_dir/server.crt" -extensions server_cert -extfile "$script_dir/ssl.cnf"

# Create client certificate
openssl req -config "$script_dir/ssl.cnf" -new -nodes -newkey rsa:4096 -keyout "$out_dir/client.key" -out "$out_dir/client.csr" -extensions client_cert -subj "/CN=admin"
openssl x509 -req -in "$out_dir/client.csr" -days 1200 -CA "$out_dir/ca.crt" -CAkey "$out_dir/ca.key" -set_serial 01 -out "$out_dir/client.crt" -extensions client_cert -extfile "$script_dir/ssl.cnf"

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

cp "$out_dir"/server.key "$out_dir"/auth.key
chown 0:65534 "$out_dir"/auth.key
chmod 640 "$out_dir"/auth.key

chown 0:65534 "$out_dir"/client.*
chmod 640 "$out_dir"/client.*
