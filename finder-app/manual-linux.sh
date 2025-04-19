#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v6.1.100
#v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
TOOLCHAIN_PATH=/home/oleksandr/UbuntuCourse/SystemProg/aarch_dev_toolchain
ASSIGNMENT2_DIR=/home/oleksandr/UbuntuCourse/SystemProg/assignment-2-smyrnoek/finder-app
ASSIGNMENT3_DIR=/home/oleksandr/UbuntuCourse/SystemProg/assignment-3-smyrnoek/finder-app

export PATH=/home/oleksandr/UbuntuCourse/SystemProg/aarch_dev_toolchain/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu/bin:$PATH
export CROSS_COMPILE=${CROSS_COMPILE}

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all -j4
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

    # Copy the modules (if needed)
    # cp -r modules/* ${OUTDIR}/modules/
fi

echo "Adding the Image in outdir"
# Copy the kernel image
cd "$OUTDIR"/linux-stable
cp arch/${ARCH}/boot/Image ${OUTDIR}/Image
# Copy the device tree blobs (DTBs)
# cp arch/${ARCH}/boot/dts/*.dtb ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p ${OUTDIR}/rootfs
mkdir -p ${OUTDIR}/rootfs/{bin,dev,etc,home,lib,lib64,proc,sbin,sys,tmp,usr,var}
mkdir -p ${OUTDIR}/rootfs/{usr/bin,usr/lib,usr/sbin,home/conf}
mkdir -p ${OUTDIR}/rootfs/var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean
    make defconfig

else
    cd busybox
fi

# TODO: Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

echo "Library dependencies"
#${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "program interpreter"
INTERPRETER_PATH=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "program interpreter" | awk '{print $NF}' | tr -d '[]')
INTERPRETER_FILE=$(find ${TOOLCHAIN_PATH} -name "$(basename $INTERPRETER_PATH)")
if [ -f "$INTERPRETER_FILE" ]; then
    cp "$INTERPRETER_FILE" ${OUTDIR}/rootfs/lib/
    echo "Copied $INTERPRETER_FILE to ${OUTDIR}/rootfs/lib/"
else
    echo "Interpreter file not found: $INTERPRETER_FILE"
fi

#${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"
SHARED_LIBRARIES=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "Shared library" | awk '{print $NF}' | tr -d '[]')


# TODO: Add library dependencies to rootfs
for LIBRARY in $SHARED_LIBRARIES; do
    # Extract just the filename from the library path
    LIBRARY_NAME=$(basename "$LIBRARY")
    
    # Use find to locate the library in your toolchain
    LIBRARY_FILE=$(find ${TOOLCHAIN_PATH} -name "$LIBRARY_NAME")
    
    # Step 3: Copy the library to /lib64 if found
    if [ -f "$LIBRARY_FILE" ]; then
        cp "$LIBRARY_FILE" ${OUTDIR}/rootfs/lib64/
        echo "Copied $LIBRARY_FILE to ${OUTDIR}/rootfs/lib64/"
    else
        echo "Library file not found: $LIBRARY_FILE"
    fi
done

# TODO: Make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# TODO: Clean and build the writer utility
# Clean up old binaries and object files without changing directories
make -C ${ASSIGNMENT2_DIR} clean
# Build the writer utility without changing directories
make -C ${ASSIGNMENT2_DIR}
cp ${ASSIGNMENT2_DIR}/writer ${OUTDIR}/rootfs/home/

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp ${ASSIGNMENT2_DIR}/{finder.sh,finder-test.sh} ${OUTDIR}/rootfs/home/
cp ${ASSIGNMENT2_DIR}/{conf/username.txt,conf/assignment.txt} ${OUTDIR}/rootfs/home/conf/

# Copy the autorun-qemu.sh script into the outdir/rootfs/home directory
cp ${ASSIGNMENT3_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# TODO: Chown the root directory
    cd ${OUTDIR}/rootfs
    # Change ownership of all files to root:root
    sudo chown -R root:root .

# TODO: Create initramfs.cpio.gz
    echo "Creating initfamfs.cpio"
    # Find all files in the current directory and create a new CPIO archive:
    find . | cpio -H newc -ov --owner root:root >${OUTDIR}/initramfs.cpio
    # After running this command, you will get a compressed file named initramfs.cpio.gz
    echo "Gzip for initramfs.cpio"
    gzip -f ${OUTDIR}/initramfs.cpio
