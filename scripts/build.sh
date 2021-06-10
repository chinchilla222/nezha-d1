#!/bin/bash

set -e

WORK_NEZHA_PATH="`pwd`"
echo $WORK_NEZHA_PATH

NEZHA_CROSS_COMPILE_PATH=riscv64-glibc-gcc-thead_20200702 
NEZHA_LINUX_VERSION=linux-5.13-rc3
NEZHA_CROSS_COMPILE=gcc

#source
NEZHA_SOURCE_PATH=${WORK_NEZHA_PATH}/opensource
NEZHA_SOURCE_KERNEL_PATH=${NEZHA_SOURCE_PATH}/linux
NEZHA_SOURCE_SBI_PATH=${NEZHA_SOURCE_PATH}/opensbi
NEZHA_SOURCE_TOOLS_PATH=${NEZHA_SOURCE_PATH}/tools/toolchain
NEZHA_SOURCE_FS_PATH=${NEZHA_SOURCE_PATH}/rootfs

#build
NEZHA_BUILD_PATH=${WORK_NEZHA_PATH}/build
NEZHA_BUILD_KERNEL_PATH=${NEZHA_BUILD_PATH}/${NEZHA_LINUX_VERSION}
NEZHA_BUILD_SBI_PATH=${NEZHA_BUILD_PATH}/opensbi-master
NEZHA_BUILD_TOOLS_PATH=${NEZHA_BUILD_PATH}/${NEZHA_CROSS_COMPILE_PATH}/bin
NEZHA_BUILD_FS_PATH=${NEZHA_BUILD_PATH}/target_rootfs
NEZHA_DEBUG_PATH=${NEZHA_BUILD_PATH}/debug

#create build dir
if [ ! -d ${NEZHA_BUILD_PATH} ] ; then
	echo ${NEZHA_BUILD_PATH}
	mkdir -p ${NEZHA_BUILD_PATH}
fi

if [ ! -d ${NEZHA_DEBUG_PATH} ] ; then
	mkdir -p ${NEZHA_DEBUG_PATH}
fi

#prepare toolchains
if [ ! -d ${NEZHA_BUILD_TOOLS_PATH} ] ; then
	#tar xvf ${NEZHA_SOURCE_TOOLS_PATH}/${NEZHA_CROSS_COMPILE_PATH}.tar.xz -C ${NEZHA_BUILD_PATH}
	cat ${NEZHA_SOURCE_TOOLS_PATH}/${NEZHA_CROSS_COMPILE_PATH}.tar.xz.* | tar xJ -C ${NEZHA_BUILD_PATH}
fi

NEZHA_CROSS_COMPILE=${NEZHA_BUILD_TOOLS_PATH}/riscv64-unknown-linux-gnu-
if [ ! -f ${NEZHA_CROSS_COMPILE}gcc ]; then
	echo "compiler err:"${NEZHA_CROSS_COMPILE} "is not exited" 
	exit 1	
fi 

echo "NEZHA_CROSS_COMPILE:"${NEZHA_CROSS_COMPILE}

#compile linux
if [ ! -f ${NEZHA_SOURCE_KERNEL_PATH}/${NEZHA_LINUX_VERSION}.tar.gz ]; then
	wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/${NEZHA_LINUX_VERSION}.tar.gz -P ${NEZHA_SOURCE_KERNEL_PATH}/
fi 

if [ ! -d ${NEZHA_BUILD_KERNEL_PATH} ] ; then
	tar xzvf ${NEZHA_SOURCE_KERNEL_PATH}/${NEZHA_LINUX_VERSION}.tar.gz  -C ${NEZHA_BUILD_PATH}
	cd ${NEZHA_BUILD_KERNEL_PATH}
	git init; git add ./; git commit -s -m "init version"
	#apply patch
	git am ${NEZHA_SOURCE_KERNEL_PATH}/*.patch
		
fi
cd ${NEZHA_BUILD_KERNEL_PATH}

if [ ! -f .config ] ; then
	make ARCH=riscv CROSS_COMPILE=${NEZHA_CROSS_COMPILE} d1_nezha_defconfig 
fi

make ARCH=riscv CROSS_COMPILE=${NEZHA_CROSS_COMPILE} all -j2


#copy Image,dtb
if [ ! -f ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/Image ] ; then
	echo "Image not exist, kernel compile failed."
	exit 1
fi

cp ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/Image ${NEZHA_DEBUG_PATH}
cp ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/dts/sunxi/d1_nezha.dtb ${NEZHA_DEBUG_PATH}

#compile sbi
if [ ! -d ${NEZHA_BUILD_SBI_PATH} ] ; then
	unzip ${NEZHA_SOURCE_SBI_PATH}/opensbi-master.zip -d ${NEZHA_BUILD_PATH}
fi

cd ${NEZHA_BUILD_SBI_PATH}
make PLATFORM=generic CROSS_COMPILE=${NEZHA_CROSS_COMPILE}

if [ ! -f ${NEZHA_BUILD_SBI_PATH}/build/platform/generic/firmware/fw_dynamic.bin ] ; then
	echo "sbi bin not exist, sbin compile failed."
	exit 1
fi

cp ${NEZHA_BUILD_SBI_PATH}/build/platform/generic/firmware/fw_dynamic.bin ${NEZHA_DEBUG_PATH}

# rootfs,gen cpio

if [ ! -d ${NEZHA_BUILD_FS_PATH} ] ; then
	tar -xzvf ${NEZHA_SOURCE_FS_PATH}/rootfs.tar.gz -C ${NEZHA_BUILD_PATH}
fi

echo "NEZHA_BUILD_FS_PATH"${NEZHA_BUILD_FS_PATH}

cd ${NEZHA_BUILD_FS_PATH}
find . | fakeroot cpio -o -Hnewc | gzip > ${NEZHA_DEBUG_PATH}/rootfs.cpio.gz

