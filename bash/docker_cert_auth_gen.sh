#!/bin/bash

mkdir temp/
cd temp/

clear

# Attempts at forceful secure setup
unset __ip__
unset __p__
__ip__=''
__p__=''


# CA private key
if [ ! -f "docker_ca_key.pem" ]; then
  echo "Please enter a secure passphrase to encrypt the CA private key."
  read -s -p "Passphrase: " __p__
  echo ""

  # Generate CA private key protected with passphrase
  echo -e "\nGenerating CA private key.\n"
  openssl \
    genrsa \
    -aes256 \
    -passout file:<(echo ${__p__}) \
    -out docker_ca_key.pem \
    4096
else
  echo -e "Using existing CA private key \"docker_ca_key.pem\"."
  echo "Please enter the CA private key passphrase."
  read -s -p "Passphrase: " __p__
  echo ""
fi

# CA self-signed certificate
if [ ! -f "docker_ca_cert.pem" ]; then
  # Generate self-signed CA certificate
  echo -e "\nGenerating CA certificate.\n"
  openssl \
    req \
    -passin file:<(echo ${__p__}) \
    -new \
    -x509 \
    -days 3650 \
    -key docker_ca_key.pem \
    -sha256 \
    -out docker_ca_cert.pem \
    -subj '/C=US/ST=Utah/L=Salt Lake City/O=CHG Healthcare Services, Inc./OU=IT Operations/CN=dev_docker_CA'
else
  echo -e "\nUsing existing CA certificate \"docker_ca_cert.pem\"."
fi

# Server private key
if [ ! -f "docker_server_key.pem" ]; then
  # Generate Server private key
  echo -e "\nGenerating server private key.\n"
  openssl \
    genrsa \
    -out docker_server_key.pem \
    4096
else
  echo -e "\nUsing existing server private key \"docker_server_key.pem\"."
fi

echo -e "\n\nPlease enter the IPv4 address of the server for which you want to generate a certificate."
read -s -p "IP: " __ip__
echo ""

ip_for_filename=$(echo ${__ip__} | sed 's/\./_/g')

# Server certificate
if [ ! -f "docker_server_${ip_for_filename}_cert.pem" ]; then
  # Generate Server CSR
  echo -e "\nGenerating server CSR.\n"
  openssl \
    req \
    -subj "/CN=dev_docker_host" \
    -sha256 \
    -new \
    -key docker_server_key.pem \
    -out docker_server.csr
  
  # Sign Server CSR
  echo -e "\nGenerating server certificate.\n"
  openssl \
    x509 \
    -req \
    -days 3650 \
    -sha256 \
    -in docker_server.csr \
    -CA docker_ca_cert.pem \
    -CAkey docker_ca_key.pem \
    -passin file:<(echo ${__p__}) \
    -CAcreateserial \
    -CAserial docker_ca_serial.srl \
    -out docker_server_${ip_for_filename}_cert.pem \
    -extfile <(echo -e "subjectAltName=IP:${__ip__},IP:127.0.0.1\nextendedKeyUsage=serverAuth")
  
  # Remove Server CSR
  rm -f docker_server.csr
else
  echo -e "\nUsing existing server certificate \"docker_server_${ip_for_filename}_cert.pem\"."
fi

# Client private key
if [ ! -f "docker_client_key.pem" ]; then
  # Generate Client private key
  echo -e "\nGenerating client private key.\n"
  openssl \
    genrsa \
    -out docker_client_key.pem \
    4096
else
  echo -e "\nUsing existing client private key \"docker_client_key.pem\"."
fi

# Client certificate
if [ ! -f "docker_client_cert.pem" ]; then
  # Generate Client CSR
  echo -e "\nGenerating client CSR.\n"
  openssl \
    req \
    -subj '/CN=client' \
    -new \
    -key docker_client_key.pem \
    -out docker_client.csr
  
  # Sign Client CSR
  echo -e "\nGenerating client certificate.\n"
  openssl \
    x509 \
    -req \
    -days 3650 \
    -sha256 \
    -in docker_client.csr \
    -CA docker_ca_cert.pem \
    -CAkey docker_ca_key.pem \
    -CAcreateserial \
    -CAserial docker_ca_serial.srl \
    -passin file:<(echo ${__p__}) \
    -out docker_client_cert.pem \
    -extfile <(echo -e "extendedKeyUsage=clientAuth")
  
  # Remove Client CSR
  rm -f docker_client.csr
else
  echo -e "\nUsing existing client certificate \"docker_client_cert.pem\"."
fi

# Attempts at forceful secure cleanup
__ip__=''
__p__=''
unset __ip__
unset __p__
