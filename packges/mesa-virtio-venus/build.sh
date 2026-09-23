#!/bin/bash

set -euo pipefail

workdir="$(pwd)/workdir"
output="$workdir/output"

mkdir -p "$workdir" "$output"

sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources

apt update
apt build-dep mesa -y > /dev/null
apt install git cmake wget zip unzip pkg-config patchelf -y > /dev/null

cd "$workdir"

wget https://dl.google.com/android/repository/android-ndk-r30-linux.zip &> /dev/null
unzip android-ndk-r30-linux.zip

export toolchain="$workdir/android-ndk-r30/toolchains/llvm/prebuilt/linux-x86_64"
export sysroot="$toolchain/sysroot"

git clone https://gitlab.freedesktop.org/mesa/mesa.git "$workdir/mesa"

cd "$workdir/mesa"

git switch --detach mesa-26.2.3

git clone --depth 1 https://github.com/termux/termux-packages "$workdir/mesa/termux-packages"

export TERMUX_PREFIX="/data/data/com.termux/files"

for p in "$workdir"/mesa/termux-packages/packages/mesa/*.patch; do
    [ -e "$p" ] || continue

    sed "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" "$p" |
        patch --silent -p1 -d "$workdir/mesa"
done

for p in "$workdir"/mesa/termux-packages/ndk-patches/30/*.patch; do
    [ -e "$p" ] || continue

    sed "s|@TERMUX_PREFIX@|$TERMUX_PREFIX|g" "$p" |
        patch --silent -p1 -d "$sysroot"
done

export CC="$toolchain/bin/aarch64-linux-android36-clang"
export CXX="$toolchain/bin/aarch64-linux-android36-clang++"
export AR="$toolchain/bin/llvm-ar"
export STRIP="$toolchain/bin/llvm-strip"
export LD="$toolchain/bin/ld.lld"

git clone --depth 1 https://github.com/JustCallMeJade/libandroid-shmem "$workdir/libandroid-shmem"

cd "$workdir/libandroid-shmem"

$CC -shared -fPIC shmem.c -o $sysroot/usr/lib/libandroid-shmem.so

cd "$workdir/mesa"

export CPPFLAGS="-D__USE_GNU"
export LDFLAGS="-landroid-shmem"

meson setup build \
    -Dplatforms=x11 \
    -Dxmlconfig=disabled \
    -Dllvm=disabled \
    -Dgallium-drivers= \
    -Dvulkan-drivers=virtio \
    --prefix "$output"

ninja -C build install

zip -r outputs.zip $output
