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
unzip android-ndk-r30-linux.zip &> /dev/null

toolchain="$workdir/android-ndk-r30/toolchains/llvm/prebuilt/linux-x86_64"
sysroot="$toolchain/sysroot"

git clone https://gitlab.freedesktop.org/mesa/mesa.git "$workdir/mesa"

cd "$workdir/mesa"

git switch --detach mesa-26.2.3

git clone --depth 1 https://github.com/termux/termux-packages "$workdir/mesa/termux-packages"

TERMUX_PREFIX="/data/data/com.termux/files"

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

# wget https://github.com/JustCallMeJade/TermuxFS-RootFS/releases/download/build-20260218/termuxfs-aarch64.tar &> /dev/null

# tar -xf termuxfs-aarch64.tar

# export TERMUX_ROOTFS="$workdir/mesa/data/data/com.termux/files/"

cat > "$workdir/android-aarch64.txt" <<EOF
[binaries]
c = ['$toolchain/bin/aarch64-linux-android36-clang', '-D__USE_GNU', '-Wno-error', '--sysroot=$sysroot']
cpp = ['$toolchain/bin/aarch64-linux-android36-clang++', '-D__USE_GNU', '-Wno-error', '--sysroot=$sysroot']
ar = '$toolchain/bin/llvm-ar'
strip = '$toolchain/bin/llvm-strip'
ld = '$toolchain/bin/ld.lld'
pkg-config = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

# git clone --depth 1 https://github.com/JustCallMeJade/libandroid-shmem "$workdir/libandroid-shmem"

# cd "$workdir/libandroid-shmem"

# $CC -shared -fPIC shmem.c -o $sysroot/usr/lib/libandroid-shmem.so

cd "$workdir/mesa"

meson setup build \
    --cross-file "$workdir/android-aarch64.txt" \
    -Dplatforms=x11 \
    -Dxmlconfig=disabled \
    -Dllvm=disabled \
    -Dgallium-drivers= \
    -Dvulkan-drivers=virtio \
    --prefix "$output" \
    -Dvalgrind=disabled \
    -Dzstd=disabled \
    -Dbuildtype=release

ninja -C build install

zip -r outputs.zip $output
