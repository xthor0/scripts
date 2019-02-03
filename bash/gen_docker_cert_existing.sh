#!/bin/bash

# display usage
# display usage
function usage() {
  echo "`basename $0`: Generate SSL certificate for Docker API"
  echo "Usage:

`basename $0` -i <ip address of server> -n <name of server>"
        exit 255
}

# get command-line args
while getopts "i:n:" OPTION; do
  case $OPTION in
    i) ipaddr="$OPTARG";;
    n) servername="$OPTARG";;
    *) usage;;
  esac
done

# validate arguments
if [ -z "${ipaddr}" -o -z "${servername}" ]; then
  usage
fi

# we need a few files
for file in ca-key.pem ca.pem key.pem; do
  if [ ! -f "${file}" ]; then
    echo "Missing file: ${file}"
    echo "Cannot proceed."
    exit 255
  fi
done

# generate the certs
openssl req -subj "/CN=docker_host_${servername}" -sha256 -new -key key.pem -out ${servername}.csr
openssl x509 -req -days 3650 -sha256 -in ${servername}.csr -CA ca.pem -CAkey ca-key.pem -out ${servername}.pem -CAcreateserial -CAserial ca.srl -extfile <(echo -e "subjectAltName=DNS.1:${servername}.mychg.com,IP:${ipaddr},IP:127.0.0.1\nextendedKeyUsage=serverAuth")

# spit out a message
echo "Cert generated: ${servername}.pem"

# make it easier to put in the pillar
cat ${servername}.pem | while read line; do echo "          ${line}"; done

exit 0
