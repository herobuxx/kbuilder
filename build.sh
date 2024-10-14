#!/bin/bash
#
# Copyright © 2024 Akif Fathur <me@buxxed.me>
#
# USage: ./build.sh
#

WORK_DIR=$(pwd)
SRC_DIR=${WORK_DIR}/src
CLANG_DIR=${WORK_DIR}/clang
INSTALL_MODULES_DIR=${SRC_DIR}/install_modules
INSTALL_DIR=${WORK_DIR}/packaging
KERNEL_URL=https://github.com/herobuxx/linux.git
KERNEL_BRANCH=6.11-main
KERNEL_VERSION=v6.11.3
CPU_CORES=32
CC_PATH="${CLANG_DIR}/bin/clang"
KERNEL_LOCALVERSION=lilium
START_TIME=$(date +%s)

CLANG_DATE=$2
if [[ "${CLANG_DATE}" == "" ]]; then
    CLANG_DATE=20241004
fi

# Cleanup directory
if [ -d "$SRC_DIR" ]; then
    if [ -d $INSTALL_DIR ]; then
        echo "Cleaning up packaging directory.."
        rm -rf $INSTALL_DIR
    fi

    if ls linux*.tar.gz 1> /dev/null 2>&1; then
        echo "Removing linux*.tar.gz file(s).."
        rm -f linux*.tar.gz
    fi

    echo "Entering source directory.."
    cd "$SRC_DIR"
    echo "Running make with mrprop.."
    make mrproper -j"$CPU_CORES"

    cd "$WORK_DIR"
else
    echo "SRC_DIR does not exist. Exiting script."
    echo "Skipping..."
fi

# Prepare Clang
if [ ! -f "${CLANG_DIR}/bin/clang" ]; then
    echo "Downloading LiliumClang..."
    mkdir -p $CLANG_DIR
    cd $CLANG_DIR
    echo "Build date: $CLANG_DATE"
    wget https://github.com/liliumproject/clang/releases/download/$CLANG_DATE/lilium_clang-$CLANG_DATE.tar.gz
    echo "Extracting LiliumClang..."
    tar -xzvf lilium_clang-$CLANG_DATE.tar.gz
    cd $WORK_DIR
else
    echo "LiliumClang binary already exists. Skipping download."
fi

# Cloning Kernel source
echo "Downloading Linux Kernel source..."
git clone $KERNEL_URL -b $KERNEL_BRANCH $SRC_DIR --depth 1
cd ${SRC_DIR}

# Step 3: Configure the Kernel
echo "Configuring the Kernel..."
if [ -f ${WORK_DIR}/config ]; then
    cp ${WORK_DIR}/config ${SRC_DIR}/.config
else
    make defconfig
fi

# Build the Kernel
echo "Building the Kernel with $CPU_CORES cores..."
make -j$CPU_CORES CC="$CC_PATH" \
    LOCALVERSION=-$KERNEL_LOCALVERSION

# Build Kernel Modules
echo "Building Kernel Modules..."
make modules \
    CC="$CC_PATH" \
    LOCALVERSION=-$KERNEL_LOCALVERSION \
    -j$CPU_CORES

# Install the Kernel to a Package Directory
echo "Installing kernel modules..."
make modules_install \
    INSTALL_MOD_PATH="$INSTALL_MODULES_DIR"  \
    CC="$CC_PATH" \
    DEPMOD=/doesnt/exist \
    INSTALL_MOD_STRIP=1 \
    LOCALVERSION=-$KERNEL_LOCALVERSION \
    -j$CPU_CORES

# Install the Kernel to a Package Directory
echo "Packaging the Kernel..."
mkdir -p $INSTALL_DIR/boot

# Copy the kernel image (bzImage)
cp ${SRC_DIR}/arch/x86/boot/bzImage $INSTALL_DIR/boot/vmlinuz-linux-$KERNEL_LOCALVERSION

# Copy the kernel modules
cp -r $INSTALL_MODULES_DIR/lib $INSTALL_DIR/lib

# Creating tarball package
echo "Creating the tarball package..."
cd $WORK_DIR
tar -czvf linux-$KERNEL_VERSION-$KERNEL_LOCALVERSION.tar.gz -C $INSTALL_DIR .

# Copy freshly generated kernel config
cat ${SRC_DIR}/.config > ${WORK_DIR}/config

# Record the end time
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

# Display the build time
echo "Kernel $KERNEL_VERSION has been built and packaged successfully!"
echo "Total build time: $(printf '%02d:%02d:%02d\n' $(($BUILD_TIME/3600)) $(($BUILD_TIME%3600/60)) $(($BUILD_TIME%60)))"
echo "You can find the tarball at $WORK_DIR/linux-$KERNEL_VERSION-$KERNEL_LOCALVERSION.tar.gz"