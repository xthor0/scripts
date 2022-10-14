#!/bin/bash

for util in fio sysbench; do
	type ${util} >& /dev/null
	if [ $? -ne 0 ]; then
		echo "Missing ${util} :: exiting."
		exit 255
	fi
done


if [ "$(uname -s)" == "Darwin" ]; then
	cpu_model="$(sysctl -n machdep.cpu.brand_string)"
else
	cpu_model="$(grep ^model\ name /proc/cpuinfo  | head -n1 | cut -d \: -f 2 | cut -b 2-)"
fi

echo "CPU Model: ${cpu_model} :: $(nproc) CPU Cores"
echo
echo "CPU Test (Single-thread)"
sysbench cpu run | grep "events per second"
echo
echo "CPU Test (Multi-thread)"
sysbench --threads=$(nproc) cpu run | grep "events per second"
echo
echo "Memory Test (Single-thread)"
sysbench memory run | egrep -i '(total operations|transferred)'
echo
echo "Memory Test (Multi-thread)"
sysbench --threads=$(nproc) memory run | egrep -i '(total operations|transferred)'

echo
echo 

echo "Creating fio test"
if test -d ${HOME}/fio; then
	echo "dir ${HOME}/fio already exists"
else
	mkdir ${HOME}/fio
	echo "created ${HOME}/fio"
fi

cat << EOF > ${HOME}/fio/ssd-test.fio
[global]
bs=4k
ioengine=libaio
iodepth=4
size=10g
direct=1
runtime=60
directory=${HOME}/fio
filename=ssd.test.file

[seq-read]
rw=read
stonewall

[rand-read]
rw=randread
stonewall

[seq-write]
rw=write
stonewall

[rand-write]
rw=randwrite
stonewall
EOF

fio ${HOME}/fio/ssd-test.fio

rm -rf ${HOME}/fio/