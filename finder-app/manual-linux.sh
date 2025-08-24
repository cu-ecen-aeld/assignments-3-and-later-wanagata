#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

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
    echo "[Script] deep clean kernel"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    echo "[Script] QEMU virt machine (defconfig)"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    echo "[Script] Build the kernel (vmlinux / Image)"
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    #$(nproc) → automatically uses all CPU cores.
    #-j4 limits to 4 cores; 
    echo "[Script] Build any kernel modules"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    echo "[Script] Build the devicetree"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "[Script] Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/
echo "[Script] Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
echo "[Script] Create necessary base directories"
mkdir -p ${OUTDIR}/rootfs/{bin,dev,etc,home,lib,lib64,proc,sbin,sys,tmp,var/log,usr/{bin,lib,sbin}}
tree ${OUTDIR}/rootfs

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    echo "[Script] Configure busybox"
else
    cd busybox
fi

# TODO: Make and install busybox
echo "[Script] Make and install busybox"
make distclean
make defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

echo "[Script] Library dependencies"
cd ${OUTDIR}/rootfs
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
echo "[Script] Add library dependencies to rootfs"
# Get the sysroot path
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
if [ ! -d "$SYSROOT" ]; then
    echo "Error: Sysroot not found at $SYSROOT"
    exit 1
fi

echo "Sysroot path: $SYSROOT"
# Copy the necessary libraries
echo "[Script] Copying necessary libraries"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library" | sed 's/.*\[\(.*\)\]/\1/' | while read lib; do
    echo "Copying library: $lib"
    # Find the library in sysroot
    if [ -f "${SYSROOT}/lib64/$lib" ]; then
        cp ${SYSROOT}/lib64/$lib ${OUTDIR}/rootfs/lib64/
    elif [ -f "${SYSROOT}/lib/$lib" ]; then
        cp ${SYSROOT}/lib/$lib ${OUTDIR}/rootfs/lib/
    else
        echo "Warning: Library $lib not found in sysroot"
    fi
done

# Copy the program interpreter
echo "[Script] Copy the program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter" | sed 's/.*\[\(.*\)\].*/\1/' | while read interpreter; do
    INTERPRETER_FILE=$(basename "$interpreter")
    echo "[Script] Copying interpreter: $INTERPRETER_FILE"
    interpreter_path=$(find "$SYSROOT" -type f -name "$INTERPRETER_FILE" | head -n 1)
    if [ -n "$interpreter_path" ]; then
        cp "$interpreter_path" "${OUTDIR}/rootfs/lib/"
        echo "Copied interpreter from $interpreter_path to ${OUTDIR}/rootfs/lib/"
    else
        echo "Warning: Interpreter $interpreter not found"
    fi
done


# TODO: Make device nodes
echo "[Script] Make device nodes"
mkdir -p ${OUTDIR}/rootfs/dev
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 622 ${OUTDIR}/rootfs/dev/console c 5 1

# TODO: Clean and build the writer utility
echo "[Script] Clean and build the writer utility"
cd ${FINDER_APP_DIR}
make clean; make writer CROSS_COMPILE=${CROSS_COMPILE}

# TODO: Copy the finder related scripts and executables to the /home directory
echo "[Script] Copy the finder related scripts and executables to the /home directory"
# on the target rootfs
cp writer ${OUTDIR}/rootfs/home
cp finder.sh ${OUTDIR}/rootfs/home
cp finder-test.sh ${OUTDIR}/rootfs/home/
cp autorun-qemu.sh ${OUTDIR}/rootfs/home/
cp -r ../conf ${OUTDIR}/rootfs/home/
# TODO: Chown the root directory
echo "[Script] Chown the root directory"
cd ${OUTDIR}/rootfs
sudo chown -R root:root *
# TODO: Create initramfs.cpio.gz
echo "[Script] Create initramfs.cpio.gz"
cd "$OUTDIR/rootfs"
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio
