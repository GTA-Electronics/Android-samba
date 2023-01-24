#!/bin/bash
CWD=$(pwd)

pr_help()
{
    echo "Required parameters:"
    echo ""
    echo "    --arch=<arm|arm64|x86|x86_64>"
    echo "    --api=<14..28>"
    echo ""
    exit 1
}

if [ -z $NDK_PATH_r17c ]; then
    echo "Path for NDK version r17c was not found."
    echo "Please define NDK_PATH_r17c variable"
    echo ""
    exit 1
fi

if [ ! -f $NDK_PATH_r17c/build/tools/make_standalone_toolchain.py ]; then
    echo "You have wrong version of NDK, please check downloaded NDK"
    echo ""
    exit 1
fi

NDK=$NDK_PATH_r17c

HOST=linux-x86_64

TOOLCHAIN_VER=4.9

TOOLCHAIN=$CWD/bin/ndk/toolchain

for opt do
    optval="${opt#*=}"
    case "${opt%=*}" in
    --arch)
        PLATFORM_ARCH="${optval}"
        ;;
    --api)
        ANDROID_VER="${optval}"
        ;;
    *)
        pr_help
        ;;
    esac
done

if [ -z $PLATFORM_ARCH ] || [ -z $ANDROID_VER ]; then
    pr_help
fi

# Flags for 32-bit ARM
if [ "$PLATFORM_ARCH" = "arm" ]; then
    ABI=arm-linux-androideabi
    TRIPLE=arm-linux-androideabi

    # Flags for ARM v7 used with flags for 32-bit ARM to compile for ARMv7
    COMPILER_FLAG="-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
    LINKER_FLAG="-march=armv7-a -Wl,--fix-cortex-a8"
elif [ "$PLATFORM_ARCH" = "arm64" ]; then
    ABI=aarch64-linux-android
    TRIPLE=aarch64-linux-android
elif [ "$PLATFORM_ARCH" = "x86" ]; then
    ABI=x86
    TRIPLE=i686-linux-android
elif [ "$PLATFORM_ARCH" = "x86_64" ]; then
    ABI=x86_64
    TRIPLE=x86_64-linux-android
else
    pr_help
fi

if [ ! -d $NDK/platforms/android-$ANDROID_VER/arch-$PLATFORM_ARCH ]; then
    echo "Platform you selected is not supported by NDK."
    echo ""
    echo "Android version: $ANDROID_VER"
    echo "Architecture:    $PLATFORM_ARCH"
    echo ""
    exit 1
fi

export CC="$CWD/cc_shim.py $TOOLCHAIN/bin/clang"
export AR=$TOOLCHAIN/$TRIPLE-ar
export RANLIB=$TOOLCHAIN/$TRIPLE-ranlib

COMPILE_SYSROOT=$TOOLCHAIN/sysroot
export CFLAGS="--sysroot=$COMPILE_SYSROOT $COMPILER_FLAG -O2 -D_FORTIFY_SOURCE=2 -D__ANDROID_API__=$ANDROID_VER -D__USE_FILE_OFFSET64=1 -fstack-protector-all -fPIE -Wa,--noexecstack -Wformat -Wformat-security"

LINK_SYSROOT=$NDK/platforms/android-$ANDROID_VER/arch-$PLATFORM_ARCH
export LDFLAGS="--sysroot=$LINK_SYSROOT $LINKER_FLAG -Wl,-z,relro,-z,now"

# Create standalone tool chain
rm -rf $TOOLCHAIN
echo "Creating standalone toolchain..."
$NDK/build/tools/make_standalone_toolchain.py --arch $PLATFORM_ARCH --api $ANDROID_VER --install-dir $TOOLCHAIN

# Configure Samba build
RUNTIME_DIR=/data/samba
echo "Configuring Samba..."
$CWD/configure --hostcc=$(which gcc) --without-ads --without-ldap --without-acl-support --without-ad-dc --cross-compile --cross-answers=build_answers --prefix=$RUNTIME_DIR \
--builtin-libraries=replace,ccan,samba-cluster-support,smbconf,smbregistry,secrets3,genrand,gse,tdb,CHARSET3,tevent-util \
--bundled-libraries=talloc,tdb,pytdb,ldb,pyldb,tevent,pytevent \
--without-quotas \
--without-utmp \
--disable-cups \
--disable-iprint \
--without-pam
