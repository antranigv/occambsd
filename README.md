## occambsd: An application of Occam's razor to FreeBSD
a.k.a. "super svelte stripped down FreeBSD"

This script leverages FreeBSD build options and a kernel configuration file
to build the minimum kernel and userland to boot under the bhyve hypervisor.

By default it builds from /usr/src to a tmpfs mount /usr/obj and a tmpfs work
directory mounted at /tmp/occambsd for speed and unobtrusiveness.

## Requirements

FreeBSD 13.0-ALPHA3 source code or later in /usr/src

## Layout

```
/tmp/occambsd
/tmp/occambsd/src.conf                      OccamBSD src.conf
/usr/src/sys/amd64/conf/OCCAMBSD            OccamBSD kernel configuration file

/tmp/occambsd/bhyve-kernel                  bhyve kernel directory
/tmp/occambsd/bhyve-mnt                     bhyve disk image mount point
/tmp/occambsd/bhyve.raw                     bhyve disk image with kernel
/tmp/occambsd/load-bhyve-vmm-module.sh      Script to load vmm.ko
/tmp/occambsd/load-bhyve-disk-image.sh      Script to load bhyve kernel from disk image
/tmp/occambsd/load-bhyve-directory.sh       Optional script to load bhyve kernel from directory
/tmp/occambsd/boot-occambsd-bhyve.sh        Script to boot bhyve
/tmp/occambsd/destroy-occambsd-bhyve.sh     Script to clean up the bhyve virtual machine

/tmp/occambsd/xen-kernel                    Xen kernel directory
/tmp/occambsd/xen-mnt                       Xen disk image mount point
/tmp/occambsd/xen.raw                       Xen disk image with kernel
/tmp/occambsd/xen-occambsd.cfg              Xen disk image boot configuration file
/tmp/occambsd/xen-occambsd-kernel.cfg       Xen directory boot configuration file
/tmp/occambsd/boot-occambsd-xen.sh          Script to boot Xen krenel from disk image
/tmp/occambsd/boot-occambsd-xen-kernel.sh   Script to boot Xen kernel from directory
/tmp/occambsd/destroy-occambsd-xen.sh       Script to clean up the Xen virtual machine

/tmp/occambsd/jail                          Jail root directory
/tmp/occambsd/jail.conf                     Jail configuration file
/tmp/occambsd/boot-occambsd-jail.sh         Script to boot the jail(8)
```

## Usage

The occambsd.sh script is position independent and can be executed anywhere on the file system:
```
\time -h sh occambsd.sh
```
All writes will be to a tmpfs mount on /usr/obj and /tmp/occambsd

The script will ask for enter at each key step, allowing you to inspect the progress, along with ask a few questions.

To boot the results under bhyve, run:
```
sh load-bhyve-vmm-module.sh
sh load-bhyve-disk-image.sh
sh boot-occambsd-bhyve.sh
< explore the VM and shut down >
sh destroy-occambsd-bhyve.sh
```

## Build times on an EPYC 7402p

buildworld:	1m14.52s

buildkernel:	12.09s

installworld: 15.02s

installkernel:	0.32s

Boot time:	Approximately two seconds

This is not a desired endorsement of GitHub
