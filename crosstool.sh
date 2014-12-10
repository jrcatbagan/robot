#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#!/usr/bin/bash
#
# File: crosstool.sh
# Created: 06, December 2014
# 
# Copyright (C) 2014 Jarielle Catbagan
#
# Licensed under BSD License
#
#
# Description:
#
# Obtains the necessary packages for configuring and building either a native- or a cross-compiler
# and then installing them in the appropriate directories.
#
# Please see configuration.txt accompanied with this file for the details/motivations behind the
# various options used during the configuration process of the various packages.
# 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BINUTILS_VERSION="2.24"
GCC_VERSION="4.9.2"
GLIBC_VERSION="2.20"
TOOLCHAIN_RELPATH=opt/crosstool
LOG=$HOME/crosstool-config.log


log()
{
	if [ $# -eq 1 ]; then
		echo -e "`date`: $1" >> $LOG
	fi
}


if [ -z $TARGET ]; then
	export TARGET="arm-unknown-linux-gnueabihf"
fi

if [ -z $PREFIX ]; then
	export PREFIX="$HOME/$TOOLCHAIN_RELPATH"
fi

if [ -z $HOST ]; then
	export HOST="x86-unknown-linux-gnu"
fi

echo $PATH | grep "$PREFIX/bin" - 1>/dev/null 2>&1
if [ $? -ne 0 ]; then
	export PATH=$PREFIX/bin:$PATH
fi


cd $HOME
if [ $? -ne 0 ]; then
	echo "error: cannot access $HOME"
	exit 1
fi

# verify if the recommended location for installing the final binaries exist
# if not make the appropriate directories, otherwise remove everything so we can start anew
if [ ! -d $TOOLCHAIN_RELPATH ]; then
	mkdir -p $TOOLCHAIN_RELPATH
else
	cd $TOOLCHAIN_RELPATH
	if [ $? -eq 0 ]; then
		rm -rf * 	
	fi
fi

rm -f $LOG
echo -e "cross-toolchain configuration log file\n\n" > $LOG

log "installing kernel headers in ${PREFIX}"
cd $HOME/linux
make ARCH=arm INSTALL_HDR_PATH=$PREFIX headers_install
log "kernel headers installed"

cd $HOME
# let's start a clean slate, so remove and make the respective 'build' directories unconditionally
rm -rf build-binutils build-gcc build-glibc
mkdir build-binutils build-gcc build-glibc


# build binutils
log "building binutils for ${TARGET} with ${PREFIX} as the system root directory"
cd $HOME/build-binutils
../binutils-${BINUTILS_VERSION}/configure --prefix=$PREFIX --target=$TARGET --with-sysroot=$PREFIX \
	--with-lib-path=/lib --disable-nls --disable-werror
make
log "installing binutils in ${PREFIX}"
make install
log "binutils installed" 


# build the gcc stage-1
log "building gcc stage-1 for ${TARGET} with ${PREFIX} as the system root directory"
cd $HOME/build-gcc
../gcc-${GCC_VERSION}/configure --prefix=$PREFIX --target=$TARGET --with-sysroot=$PREFIX \
	--with-local-prefix=$PREFIX --with-native-system-header-dir=$PREFIX/include \
	--without-headers --with-newlib --disable-shared --disable-threads --disable-multilib \
	--disable-libgomp --disable-libquadmath --disable-libsanitizer --disable-libssp \
	--enable-languages=c
make all-gcc
log "installing gcc stage-1 in ${PREFIX}"
make install-gcc
log "gcc stage-1 installed"
log "building libgcc for gcc stage-1"
make all-target-libgcc
log "installing libgcc for gcc stage-1 in ${PREFIX}"
make install-target-libgcc
log "libgcc for gcc stage-1 installed"


# build glibc
log "building glibc for ${TARGET}"
cd $HOME/build-glibc
CC="${TARGET}-gcc" AR="${TARGET}-ar" RANLIB="${TARGET}-ranlib" ../glibc-${GLIBC_VERSION}/configure \
	--prefix=$PREFIX --host=$TARGET --enable-kernel=2.6.32 --with-binutils=$PREFIX/bin \
	--with-headers=$PREFIX/include
make
log "installing glibc in ${PREFIX}"
make install
log "glibc installed"


log "building gcc final for ${TARGET} with ${PREFIX} as the system root directory"
cd $HOME/build-gcc
if [ $? -eq 0 ]; then
	rm -rf *
fi
../gcc-${GCC_VERSION}/configure --prefix=$PREFIX --target=$TARGET --with-sysroot=$PREFIX \
	--with-local-prefix=$PREFIX --with-native-system-header-dir=/include \
	--disable-nls --disable-multilib --enable-threads=posix --enable-languages=c,c++
make AS_FOR_TARGET="${TARGET}-as" LD_FOR_TARGET="${TARGET}-ld"
log "installing gcc final in ${PREFIX}"
make install
log "gcc final installed"







