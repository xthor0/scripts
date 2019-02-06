#!/bin/bash

# display usage
function usage() {
  echo "`basename $0`: Generate SSL certificate for Docker API"
  echo "Usage:

`basename $0` [ -n <servername> -i <ip address> ] | [ -c ]"
        exit 255
}

# get command-line args
while getopts "n:i:c" OPTION; do
  case $OPTION in
    n) servername="${OPTARG}";;
    i) ipaddr="${OPTARG}";;
    c) clientcert="yes";;
    *) usage;;
  esac
done

# validate arguments - ensure client cert and server cert options are not mixed
if [ -z "${servername}" -a -z "${ipaddr}" ]; then
    if [ -z "${clientcert}" ]; then
        echo "Can't mix client cert and server cert options!"
        usage
    fi
else
    if [ -n "${clientcert}" ]; then
        echo "Can't mix client cert and server cert options!"
        usage
    fi
fi

if [ -n "${num}" ]; then
    # make sure that the argument passed is a valid number
    re='^[0-9]+$'
    if ! [[ ${num} =~ ${re} ]] ; then
        echo "Error: ${num} is not a number!"
        usage
    fi
else
    num=6
fi

# functions
function gen_ca_key() {
    openssl genrsa -out ca-key.pem 4096
}

function gen_ca() {
    openssl req -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem \
    -subj "/C=US/ST=Utah/L=Salt Lake City/O=CHG Healthcare Services, Inc./OU=IT Operations/CN=docker_CA_dev"
}

function gen_key() {
    if [ -z "${1}" ]; then
        echo "This function expects to be passed the name of the key to generate! Exiting."
        exit 255
    fi
    openssl genrsa -out ${1} 4096
}

function gen_csr() {
    if [ -z "${1}" ]; then
        echo "This function must be called with the servername to gen a CSR!"
        exit 255
    fi

    if [ -z "${2}" ]; then
        echo "This function must be called with the key to sign the CSR against."
        exit 255
    fi
    openssl req -subj "/CN=docker_host_${1}" -sha256 -new -key ${2} -out ${1}.csr
}

function sign_server_csr() {
    if [ -z "${1}" ]; then
        echo "sign_server_csr function expects 1 arg: servername"
        exit 255
    fi

    if [ -n "${2}" ]; then
        ext_SAN="DNS.1:${1},IP:${2},IP:127.0.0.1"
    else
        ext_SAN="DNS.1:${1},IP:127.0.0.1"
    fi

    openssl x509 -req -days 3650 -sha256 -in ${1}.csr -CA ca.pem -CAkey ca-key.pem -out ${1}.pem -CAcreateserial -extfile <(echo -e "subjectAltName = ${ext_SAN}\nextendedKeyUsage=serverAuth")
}

function sign_client_csr() {
    if [ -z "${1}" ]; then
        echo "sign_client_csr expects 1 arg: servername"
        exit 255
    fi
    openssl x509 -req -days 3650 -sha256 -in ${1}.csr -CA ca.pem -CAkey ca-key.pem -out ${1}.pem -CAcreateserial -extfile <(echo -e "extendedKeyUsage=clientAuth")
}

if [ -f ca-key.pem ]; then
    echo "Using existing ca-key.pem file"
else
    gen_ca_key
    if [ $? -eq 0 ]; then
        echo "CA key generated successfully"
    else
        echo "Error during cert creation process - see output above."
        exit 255
    fi

fi

if [ -f ca.pem ]; then
    echo "Using existing ca.pem file"
else
    # since this PXT has obviously never had keys generated, let's go ahead and do that
    gen_ca
    if [ $? -eq 0 ]; then
        echo "CA generated successfully"
    else
        echo "Error during cert creation process - see output above."
        exit 255
    fi
fi

# generate new server and client keys, if necessary
for key in server-key.pem client-key.pem; do
    if [ -f ${key} ]; then
        echo "Using existing key: ${key}"
    else
        echo "Generating key ${key}"
        gen_key ${key}
        if [ $? -ne 0 ]; then
            echo "Error generating key ${key} - exiting."
            exit 255
        fi
    fi
done

if [ "${clientcert}" == "yes" ]; then
    # generate single client auth cert - used by Jenkins
    if [ -f jenkins.pem ]; then
        echo "Client cert has already been generated"
    else
        gen_csr jenkins client-key.pem && sign_client_csr jenkins
        if [ $? -ne 0 ]; then
            echo "Error generating client cert - see output above."
            exit 255
        else
            rm jenkins.csr
        fi
    fi
else
    # generate CSRs and sign them for each server specified in num (if they don't exist)
    if [ -f ${servername}.pem ]; then
        echo "Cert already generated for: ${servername}"
    else
        gen_csr ${servername} server-key.pem && sign_server_csr ${servername} ${ipaddr}
        if [ $? -eq 0 ]; then
            echo "Cert generated for: ${servername}"
            rm ${servername}.csr
        else
            echo "Error during cert creation process - see output above."
            exit 255
        fi
    fi
fi

exit 0

