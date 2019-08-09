#!/bin/bash

# display usage
function usage() {
    echo "Error: Incorrect options specified!"
    echo
	echo "$(basename $0): Build a template for use with VirtualBox."
    echo
	echo "Usage:

$(basename $0) -n <name of virtualbox vm> -s <source VDI image>"

	exit 255
}


# we need command-line options
while getopts "n:s:" opt; do
	case $opt in
		n)
			name=${OPTARG};;
        s)
            source=${OPTARG};;
        *)
            usage;;
	esac
done

# validate arguments...
if [ -z "${name}" -o -z "${source}" ]; then
    usage
fi

# make sure I can access the source VDI
if [ ! -f ${source} ]; then
    echo "Unable to find source VDI: ${source} -- exiting!"
    exit 255
fi

# generate metadata
isotmp=$(mktemp -d)

cat << EOF > ${isotmp}/meta-data
instance-id: 1
local-hostname: ${name}
EOF

# generate userdata
cat << EOF > ${isotmp}/user-data
#cloud-config
password: p@ssw0rd
chpasswd: { expire: False }
ssh_pwauth: True
ssh_authorized_keys:
    - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfu9au0EkA02pnruvqLcquikJim4VgQg61YxwG0LauDv+qM0j4EPDfzQtN3GMfyPs/i79NeNNndvfc2vqYJt8sVwjegoNF9h8jDytaWZ7zzblhY7qBkwtAVZ6ADgTY/w28CkB80dRPey2E4FGxING6AzieYwoHsKmaMt6IumOJlo01HoeouW7OP8qg51n8EHKmov5oA4DzzDx/UkS0aDDKpp38hIj0DHkcK8jhi5eZoEM7hOgaW+Efj6t/XzpoOhQVytsJXxqzZ/+4UDVfJ3FTQLmI+hdymbyxYL5i2FCK5kMldGyZuZz9h9ikM9xHWSmKIeTevut9/chveUR/W/E2qqziqm8fCoZZ2WIHfhy+Bt0OcLUro2Gpe7S0i8uCbvNK60OpE+hf9GxAv+G0UUCuSxJtKqrpgi5xNifvXaT3pk5Uxr/1+g+tiMyoaZxCmJPz7IZU7y9lurTAhYT0HgkcU4OZpGS1/x+rGu2f0un3UkUJyYFpgjfjw9iu9Y/0H7k= bbrown@bbrown-l
EOF


vboxmanage list vms | grep -wq ${name}
if [ $? -eq 1 ]; then
    vboxmanage createvm --name ${name} --ostype Linux_64 --register
    if [ $? -eq 0 ]; then
        VBoxManage modifyvm ${name} --memory 1024
        if [ $? -eq 0 ]; then
            vboxmanage modifyvm ${name} --nic1 hostonly --hostonlyadapter1 vboxnet0
            if [ $? -eq 0 ]; then
                cp ${source} ~/VirtualBox\ VMs/${name}/${name}.vdi
                if [ $? -eq 0 ]; then
                    VBoxManage storagectl ${name} --name "SATA Controller" --add sata --controller IntelAhci --portcount 2
                    if [ $? -eq 0 ]; then
                        VBoxManage storageattach ${name} --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/${name}/${name}.vdi
                        if [ $? -eq 0 ]; then
                            # generate the ISO
                            iso="${HOME}/VirtualBox VMs/${name}/${name}-cidata.iso"
                            pushd ${isotmp}
                            genisoimage -output "${iso}" -volid cidata -joliet -rock user-data meta-data || exit 255
                            popd
                            VBoxManage storageattach ${name} --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "${iso}"
vboxmanage startvm ${name}
                            if [ $? -eq 0 ]; then
                                retval=0
                            fi
                        else
                            retval=1
                        fi
                    else
                        retval=1
                    fi
                else
                    retval=1
                fi
            else
                retval=1
            fi
        else
            retval=1
        fi
    else
        retval=1
    fi
else
    echo "VM already exists."
    retval=1
fi

if [ ${retval} -eq 1 ]; then
    echo "Error creating VM ${name} -- see output above."
else
    rm -rf ${isotmp}
    echo "VM ${name} created successfully."
fi
