#!/bin/bash
################################################################################
#
# The script for build D1 source.
#
################################################################################

set -e

WORK_NEZHA_PATH="`pwd`"
echo $WORK_NEZHA_PATH

NEZHA_CROSS_COMPILE_PATH=riscv64-glibc-gcc-thead_20200702 
NEZHA_LINUX_VERSION=linux-5.13-rc3
NEZHA_CROSS_COMPILE=gcc

#source
NEZHA_SOURCE_PATH=${WORK_NEZHA_PATH}/resource
NEZHA_SOURCE_KERNEL_PATH=${NEZHA_SOURCE_PATH}/linux
NEZHA_SOURCE_SBI_PATH=${NEZHA_SOURCE_PATH}/opensbi
NEZHA_SOURCE_TOOLS_PATH=${NEZHA_SOURCE_PATH}/tools
NEZHA_SOURCE_FS_PATH=${NEZHA_SOURCE_PATH}/rootfs

#build
NEZHA_BUILD_PATH=${WORK_NEZHA_PATH}/build
NEZHA_BUILD_KERNEL_PATH=${NEZHA_BUILD_PATH}/${NEZHA_LINUX_VERSION}
NEZHA_BUILD_SBI_PATH=${NEZHA_BUILD_PATH}/opensbi-master
NEZHA_BUILD_TOOLS_PATH=${NEZHA_BUILD_PATH}/${NEZHA_CROSS_COMPILE_PATH}/bin
NEZHA_BUILD_FS_PATH=${NEZHA_BUILD_PATH}/target_rootfs
NEZHA_DEBUG_PATH=${NEZHA_BUILD_PATH}/debug


# prepre build dir
function creat_output()
{
	echo "ctreat output dir"

	if [ ! -d ${NEZHA_BUILD_PATH} ] ; then
		echo ${NEZHA_BUILD_PATH}
		mkdir -p ${NEZHA_BUILD_PATH}
	fi

	if [ ! -d ${NEZHA_DEBUG_PATH} ] ; then
		mkdir -p ${NEZHA_DEBUG_PATH}
	fi
}

#prepare toolchains
function prepare_tools()
{
	echo "prepare tools"
	if [ ! -d ${NEZHA_BUILD_TOOLS_PATH} ] ; then
		#tar xvf ${NEZHA_SOURCE_TOOLS_PATH}/${NEZHA_CROSS_COMPILE_PATH}.tar.xz -C ${NEZHA_BUILD_PATH}
		cat ${NEZHA_SOURCE_TOOLS_PATH}/toolchain/${NEZHA_CROSS_COMPILE_PATH}.tar.xz.* \
			| tar xJ -C ${NEZHA_BUILD_PATH}
	fi

	NEZHA_CROSS_COMPILE=${NEZHA_BUILD_TOOLS_PATH}/riscv64-unknown-linux-gnu-
	if [ ! -f ${NEZHA_CROSS_COMPILE}gcc ]; then
		echo "compiler err:"${NEZHA_CROSS_COMPILE} "is not exited"
		exit 1
	fi
	echo "NEZHA_CROSS_COMPILE:"${NEZHA_CROSS_COMPILE}
}

#compile linux
function mkkernel()
{
	if [ ! -f ${NEZHA_SOURCE_KERNEL_PATH}/${NEZHA_LINUX_VERSION}.tar.gz ]; then
		wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/${NEZHA_LINUX_VERSION}.tar.gz \
			-P ${NEZHA_SOURCE_KERNEL_PATH}/
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
	if [ ! -f ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/Image ] ; then
		echo "Image not exist, kernel compile failed."
		exit 1
	fi

	${NEZHA_SOURCE_TOOLS_PATH}/mkbootimg --kernel ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/Image \
		--board sun20i_riscv --base 0x40200000 --kernel_offset 0  -o ${NEZHA_DEBUG_PATH}/boot.img

	cp ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/Image ${NEZHA_DEBUG_PATH}
	cp ${NEZHA_BUILD_KERNEL_PATH}/arch/riscv/boot/dts/allwinner/*.dtb ${NEZHA_DEBUG_PATH}/d1.dtb

}

#compile sbi
function mksbi()
{
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
}

#rootfs,gen cpio,ext4
function mkrootfs()
{
	if [ ! -d ${NEZHA_BUILD_FS_PATH} ] ; then
		tar -xzvf ${NEZHA_SOURCE_FS_PATH}/rootfs.tar.gz -C ${NEZHA_BUILD_PATH}
	fi

	echo "NEZHA_BUILD_FS_PATH"${NEZHA_BUILD_FS_PATH}

	cd ${NEZHA_BUILD_FS_PATH}
	find . | fakeroot cpio -o -Hnewc | gzip > ${NEZHA_DEBUG_PATH}/rootfs.cpio.gz

	cd ${NEZHA_DEBUG_PATH}
	${NEZHA_SOURCE_TOOLS_PATH}/make_ext4fs -l 1024M ${NEZHA_DEBUG_PATH}/roofs.ext4 ${NEZHA_BUILD_FS_PATH}/

}

case "$1" in
	kernel)
		creat_output
		prepare_tools
		mkkernel
		;;
	sbi)
		creat_output
		prepare_tools
		mksbi
		;;
	fs)
		creat_output
		prepare_tools
		mkrootfs
		;;
	*)
		creat_output
		prepare_tools
		mkkernel
		mksbi
		mkrootfs
		echo -e "\n\033[0;31;1m compile successful\033[0m\n\n"
		;;
esac

