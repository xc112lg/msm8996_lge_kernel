#!/bin/bash
#
# Created by stendro and edited by AShiningRay. Based on build script by jcadduono.
#
# This script copies the dtb-embedded kernel, and modules, to the "OUTDIR" directory.
# It also copies Swan2000 specific AnyKernel3 files and creates a flashable zip.
# You can simply run ./copy_finished.sh after doing ./build.sh - it knows which device you built for.

RDIR=$(pwd)
BDIR=${RDIR}/build

# color codes
COLOR_N="\033[0m"
COLOR_R="\033[0;31m"
COLOR_G="\033[1;32m"

# intended android version
ADROID="Android 12.1/13"

ABORT() {
	echo -e $COLOR_R"Error: $*"
	exit 1
}

DEVICE=$(cat "${BDIR}/DEVICE") \
		|| ABORT "No device file found in ${BDIR}"

VER=$(cat "${RDIR}/VERSION") \
		|| ABORT "No version file found in ${RDIR}"

COMP=$(cat "${BDIR}/COMPRESSION") \
		|| ABORT "No compression file found in ${BDIR}"

BVER=$(cat ${RDIR}/VERSION | cut -f1 -d'-')
BDATE=$(LC_ALL='en_US.utf8' date '+%b %d %Y')
GBRANCH=$(git rev-parse --abbrev-ref HEAD)
GREPO=$(git remote get-url origin)

OUTDIR=out
AK3DIR=${RDIR}/Swan2000
GITCOM=${BDIR}/GITCOMMITS
MOD_DIR=${BDIR}/lib/modules
INITRC_NAME=init.swan2ktweaks.rc
MDIR=modules/system/lib/modules
KERN_DIR=${BDIR}/arch/arm64/boot
BANNER_BETA=${AK3DIR}/banner-beta
DDIR=${RDIR}/${OUTDIR}/${DEVICE}
INIT_FILE_G6=${AK3DIR}/init-g6
INIT_FILE=${AK3DIR}/init
BANNER=${AK3DIR}/banner

CLEAN_DIR() {
	echo "Cleaning folder..."
	rm -rf $DDIR
	rm -f $RDIR/$OUTDIR/${DEVICE}_${VER}-Swan2000.zip
}

SETUP_DIR() {
	echo "Setting up folder..."
	mkdir -p $RDIR/$OUTDIR
	unzip -q $AK3DIR/ak-root.zip -d $DDIR \
		|| ABORT "Failed to unzip *ak-root.zip*"
	cp $AK3DIR/update-binary $DDIR/META-INF/com/google/android \
		|| ABORT "Failed to copy *update-binary*"
	[ -e "$GITCOM" ] && cp $GITCOM $DDIR/gitlog &&
	sed -i '1iVersion: '$VER'\nBuild date: '"$BDATE"'\n'$GREPO'/commits/'$GBRANCH'\
		\nThe last 50 commits:\n' $DDIR/gitlog \
		|| echo -e $COLOR_R"Failed to create gitlog"$COLOR_G "Continuing..."$COLOR_N
}

COPY_AK() {
	echo "Copying AnyKernel3 files..."
	if grep -q 'BETA' $RDIR/VERSION; then
	  cp $BANNER_BETA $DDIR/banner \
		|| ABORT "Failed to copy Swan2000's BETA banner"
	  echo "  ${BVER} ${ADROID}" > $DDIR/version
	else
	  cp $BANNER $DDIR/banner \
		|| ABORT "Failed to copy Swan2000's banner"
	  echo "  ${VER} ${ADROID}" > $DDIR/version
	fi
	source $AK3DIR/ak-template.sh > $DDIR/anykernel.sh \
		|| ABORT "Failed to generate *anykernel.sh*"
}

COPY_INIT() {
	if [ "$DEVICE" = "H870" ] || [ "$DEVICE" = "US997" ] || [ "$DEVICE" = "H872" ]; then
	  echo "Copying init file (G6)..."
	  cp $INIT_FILE_G6 $DDIR/ramdisk/$INITRC_NAME \
		|| ABORT "Failed to copy G6's init file"
	else
	  echo "Copying init file..."
	  cp $INIT_FILE $DDIR/ramdisk/$INITRC_NAME \
		|| ABORT "Failed to copy G5&V20's init file"
	fi
	echo "import /$INITRC_NAME" > $DDIR/patch/init_rc-mod \
		|| ABORT "Failed to make Swan2000's init_rc-mod"
}

COPY_KERNEL() {
	echo "Copying kernel image..."
	cp $KERN_DIR/Image.${COMP}-dtb $DDIR \
		|| ABORT "Failed to copy kernel image"
	if grep -q 'CONFIG_MODULES=y' $BDIR/.config; then
	  echo "Copying kernel modules..."
	  find $MOD_DIR/ -name '*.ko' -exec cp {} $DDIR/$MDIR \; \
		|| ABORT "Failed to copy the kernel's modules"
	fi
}

ZIP_UP() {
	echo "Creating AnyKernel3 archive..."
	cd $DDIR
	OUTZIP=$OUTDIR/${DEVICE}_${VER}-Swan2000.zip
	ZIPPATH=$RDIR/$OUTZIP
	zip -7qr $ZIPPATH * \
		|| ABORT "Failed to create zip archive"
}

cd "$RDIR" || ABORT "Failed to enter ${RDIR}"
echo -e $COLOR_G"Preparing ${DEVICE} ${VER}"$COLOR_N

CLEAN_DIR
SETUP_DIR
COPY_AK
COPY_INIT
COPY_KERNEL
ZIP_UP
echo -e $COLOR_G"Finished! -- Flashable zip is located at: ${OUTZIP}"
