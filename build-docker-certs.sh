#!/usr/bin/env bash
# build certs scripts

set -e

if [[ ! -n "$1" ]];then
    exit 1
fi
if [[ ! -d $1 ]];then
    mkdir -p $1
fi
cd $1
touch ~/.rnd

if [[ ! -e "ca-key.pem" ]];then
cat > openssl.cnf <<EOF
[ req ]
default_bits = 2048
default_md = sha256
distinguished_name = req_distinguished_name

[req_distinguished_name]


[ v3_ca ]
keyUsage = critical, keyCertSign, cRLSign
basicConstraints = critical, CA:true, pathlen:2
subjectKeyIdentifier = hash
authorityKeyIdentifier=keyid

[ v3_req_client ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage= clientAuth
basicConstraints = critical, CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier=keyid
EOF

# ca cert
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/C=CN/ST=GuangZhou/L=GuangZhou/O=k8s/OU=k8s/CN=kubernetes" -config openssl.cnf -extensions v3_ca
fi
if [[ -n "$2" ]];then
cat > openssl-$2.cnf <<EOF
[ v3_req_server ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage=serverAuth
basicConstraints = critical, CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier=keyid
subjectAltName = @alt_names_server

[ alt_names_server ]
IP.1 = 127.0.0.1
IP.2 = $2
EOF
# docker server cert
openssl genrsa -out docker-key-$2.pem 2048
openssl req -new -key docker-key-$2.pem -out docker-$2.csr -subj "/C=CN/ST=GuangZhou/L=GuangZhou/O=k8s/OU=k8s/CN=docker-server" -config openssl.cnf
openssl x509 -req -in docker-$2.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out docker-$2.pem -days 10000 -extensions v3_req_server -extfile openssl-$2.cnf
fi
# docker client cert
if [[ ! -e client.pem ]];then
openssl genrsa -out client-key.pem 2048
openssl req -new -key client-key.pem -out client.csr -subj "/C=CN/ST=GuangZhou/L=GuangZhou/O=k8s/OU=k8s/CN=docker-client" -config openssl.cnf
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client.pem -days 10000 -extensions v3_req_client -extfile openssl.cnf
fi

# rm *.csr *.srl file
rm -rf docker-$2.csr
