#!/bin/sh
#-
# SPDX-License-Identifier: BSD-2-Clause-FreeBSD
#
# Copyright 2022, 2023 Michael Dexter
# All rights reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted providing that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Version v1.1


# VARIABLES - NOTE THE VERSIONED ONE

work_dir="/root/imagine-work"
vm_name="vm0"

image_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.raw"

image=$( basename $image_url )

# USER INTERACTION: ANSWER ALL QUESTIONS IN ADVANCE

mustgrow="no"

echo ; echo Is the target a disk image or hardware device?
echo -n "(img/dev): " ; read target

if [ "$target" = "img" ] ; then

	[ -d "${work_dir}" ] || mkdir -p "${work_dir}"	

	if [ "$mustgrow" = "no" ] ; then
		echo ; echo Grow the root partition from the default 2G?
		echo -n "(n<Size in G> i.e. 10G): " ; read grow
		# Need a better variable than grow
		if [ "$grow" -lt 5 ] ; then
			{ echo Invalid input ; exit 1 ; }
# THIS WILL BE AN ISSUE
#		[ "$grow" = "y" ] 

			mustgrow="yes"
		fi
	fi

	if [ "$mustgrow" = "yes" ] ; then
		echo ; echo Grow the VM image from 2G? i.e. 10G
		echo ; echo -n "New VM image size: " ; read newsize
# Would be nice to valildate this input
	fi

	echo ; echo Create a VMDK wrapper for the image?
	echo -n "(y/n): " ; read vmdk
	[ "$vmdk" = "y" -o "$vmdk" = "n" ] || { echo Invalid input ; exit 1 ; }

elif [ "$target" = "dev" ] ; then

	mustgrow="yes"
	devices=$( sysctl -n kern.disks )
	for device in $devices ; do
		echo
		echo $device
		diskinfo -v $device | grep descr
		diskinfo -v $device | grep bytes
		echo
	done

	mdconfig -lv

	echo ; echo What device would you like to dd the VM image to?
	echo -n "(Device): " ; read target_device

	echo ; echo WARNING! ; echo
	echo Writing to $target_device is destructive!
	echo ; echo Continue?
	echo -n "(y/n): " ; read warning
	[ "$warning" = "y" -o "$warning" = "n" ] || \
		{ echo Invalid input ; exit 1 ; }
	if [ "$warning" = "y" ] ; then
# Add a check if the devices is mounted?
	fi

else
	echo Invalid input
	exit 1
fi

echo ; echo Generate bhyve VM guest boot script?
echo -n "(y/n): " ; read bhyve
[ "$bhyve" = "y" -o "$bhyve" = "n" ] || \
	{ echo Invalid input ; exit 1 ; }


# QUESTIONS ANSWERED, ON TO SLOW OPERATIONS

[ -d "${work_dir}/debian/debian" ] || \
	mkdir -p "${work_dir}/debian"
[ -d "${work_dir}/debian" ] || \
	{ echo "mkdir -p $work_dir/debian failed" ; exit 1 ; }

cd "$work_dir/debian"

if [ -f "$work_dir/debian/$image" ] ; then
	echo ; echo $work_dir/debian/$image exists. Reuse?
	echo -n "(y/n):" ; read reuse
	[ "$reuse" = "y" -o "$reuse" = "n" ] || \
		{ echo Invalid input ; exit 1 ; }
	if [ "$reuse" = "n" ] ; then

echo
echo "Fetching fresh nocloud image to $work_dir/debian/$image if out of date"
# -i will fail if the comparison file is missing
# Is the -i test failing on Debian?
		fetch -a -i "$work_dir/debian/$image" "$image_url" || \
		        { echo fetch failed ; exit 1 ; }
	fi
else
		echo "Fetching nocloud image to $work_dir/debian/$image"
		fetch -a "$image_url" || \
			{ echo fetch failed ; exit 1 ; }
fi

[ -f $work_dir/debian/$image ] || { echo fetch failed ; exit 1 ; }

[ -f "$work_dir/debian/vm.raw" ] && rm "$work_dir/debian/vm.raw"
rm $work_dir/debian/*.sh > /dev/null 2>&1
rm $work_dir/debian/*.vmdk > /dev/null 2>&1

if [ "$target" = "dev" ] ; then
	[ -f $work_dir/debian/$image ] || \
		{ echo $work_dir/debian/$image missing ; exit 1 ; }

	echo Imaging $work_dir/debian/$image to /dev/$target_device
	\time -h dd if=/$work_dir/debian/$image \
		of=/dev/$target_device bs=1m status=progress \
		iflag=fullblock || \
			{ echo dd failed ; exit 1 ; }

	echo ; echo Recovering $target_device partitioning
	gpart recover $target_device
else
	echo ; echo Copying $work_dir/debian/$image to $work_dir/vm.raw
	cp -p $work_dir/debian/$image $work_dir/debian/vm.raw || \
		{ echo cp failed ; exit 1 ; }

	[ -f "$work_dir/debian/vm.raw" ] || { echo cp failed ; exit 1 ; }
fi


if [ "$mustgrow" = "yes" ] ; then
	if [ "$target" = "img" ] ; then
		# Relying on growfs for now!
		echo ; echo Truncating $work_dir/debian/vm.raw
		truncate -s $newsize $work_dir/debian/vm.raw || \
			{ echo truncate failed ; exit 1 ; }
		ls -lh $work_dir/debian/vm.raw
echo DEBUG DID THAT WORK? ; read work




	fi
else
	echo Device growth is relying on growfs for now
fi


# OPTIONAL bhyve VM SUPPORT

if [ "$bhyve" = "y" ] ; then
	if [ "$target" = "img" ] ; then
		if [ "$vmdk" = "y" ] ; then
			bhyve_img="$work_dir/debian/vm-flat.vmdk"
		else
			bhyve_img="$work_dir/debian/vm.raw"
		fi
	else
		bhyve_img="/dev/$target_device"
	fi

	cat << EOF > "${work_dir}/debian/boot-bhyve.sh"
[ -e /dev/vmm/$vm_name ] && { bhyvectl --destroy --vm=$vm_name ; sleep 1 ; }
kldstat -q -m vmm || kldload vmm
sleep 1
bhyve -m 1024 -H -A \\
	-l com1,stdio \\
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \\
	-s 0,hostbridge \\
	-s 2,virtio-blk,$bhyve_img \\
	-s 31,lpc \\
	$vm_name

# Devices you may want to add:
# -s 30:0,fbuf,tcp=0.0.0.0:5900,w=1024,h=768,wait \\
# -s 3,virtio-net,tap0 \\

sleep 2
bhyvectl --destroy --vm=$vm_name
EOF
	echo ; echo Note: ${work_dir}/debian/boot-bhyve.sh
fi


# OPTIONAL VMDK WRAPPER

# THIS WILL RENAME THE DISK IMAGE AND BREAK BHYVE/XEN

if [ "$vmdk" = "y" ] ; then
	vmdk_img="$work_dir/debian/vm.raw"

	vmdk_img_base="${vmdk_img%.raw}"

	# Assuming blocksize of 512
	size_bytes="$( stat -f %z "$vmdk_img" )"
	RW=$(( "$size_bytes" / 512 ))
	cylinders=$(( "$RW" / 255 / 63 ))

cat << EOF > "${vmdk_img_base}.vmdk"
# Disk DescriptorFile
version=1
CID=12345678
parentCID=ffffffff
createType="vmfs"

RW $(( "$size_bytes" / 512 )) VMFS "${vmdk_img_base}-flat.vmdk"

# The Disk Data Base 
#DDB

ddb.adapterType = "lsilogic"
ddb.encoding = "UTF-8"
ddb.geometry.cylinders = "$cylinders"
ddb.geometry.heads = "255"
ddb.geometry.sectors = "63"
ddb.longContentID = "0123456789abcdefghijklmnopqrstuv"
ddb.toolsInstallType = "0"
ddb.toolsVersion = "2147483647"
ddb.virtualHWVersion = "4"
EOF
	echo ; echo The resulting "${vmdk_img_base}.vmdk" wrapper reads: ; echo
	cat "${vmdk_img_base}.vmdk"
	echo ; echo Renaming "$vmdk_img" to "${vmdk_img_base}-flat.vmdk"

	mv "$vmdk_img" "${vmdk_img_base}-flat.vmdk"
fi

# Could make this conditional on expanded or device
echo ; echo You may need to run in the VM:
echo ; echo growpart /dev/vda 1
echo resize2fs /dev/vda1
exit 0
