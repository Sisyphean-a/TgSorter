#!/usr/bin/env bash
# 在 Linux/WSL 中构建 Android TDLib 预览库；NDK 使用 r28 或更高版本。
set -euo pipefail

: "${ANDROID_NDK_HOME:?请设置 Linux 版 Android NDK 的目录}"
revision=03220f6b3043c6fd7785fbf0901d63f19ad19974
openssl_version=3.5.9
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
output=${1:-"$root/build/tdlib-preview/jniLibs"}
[[ $output = /* ]] || { echo '输出目录须为绝对路径' >&2; exit 2; }
ndk=$(cd -- "$ANDROID_NDK_HOME" && pwd)
toolchain="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
for tool in curl sha256sum cmake ninja gperf make perl python3; do
  command -v "$tool" >/dev/null || { echo "缺少构建工具：$tool" >&2; exit 2; }
done
[[ -x "$toolchain/llvm-strip" ]] || { echo '需要 Linux x86_64 版 NDK' >&2; exit 2; }

work=$(mktemp -d "${TDLIB_BUILD_TMPDIR:-/tmp}/tgsorter-tdlib.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
fetch() {
  curl --fail --location --retry 2 --output "$work/$2" "$1"
  printf '%s  %s\n' "$3" "$work/$2" | sha256sum -c -
}
fetch "https://codeload.github.com/tdlib/td/tar.gz/$revision" td.tar.gz 006ab80d7111a676928378d709c8e67f17b41729b28d5a7c10d13441c6703bc2
fetch "https://github.com/openssl/openssl/releases/download/openssl-$openssl_version/openssl-$openssl_version.tar.gz" openssl.tar.gz 603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
mkdir "$work/td" "$work/openssl"
tar -xf "$work/td.tar.gz" --strip-components=1 -C "$work/td"
tar -xf "$work/openssl.tar.gz" --strip-components=1 -C "$work/openssl"

jobs=${TDLIB_BUILD_JOBS:-4}
cmake -G Ninja -S "$work/td" -B "$work/host" -DTD_GENERATE_SOURCE_FILES=ON -DTD_GIT_COMMIT_HASH="$revision"
cmake --build "$work/host" --target prepare_cross_compiling --parallel "$jobs"

# 预览包暂只交付真机 arm64，稳定包原来的 ABI 不变。
(
  cd "$work/openssl"
  export ANDROID_NDK_ROOT="$ndk" PATH="$toolchain:$PATH"
  ./Configure android-arm64 -D__ANDROID_API__=24 no-shared no-tests --prefix="$work/ssl" --libdir=lib
  make -j"$jobs" build_libs
  make install_dev
)
cmake -G Ninja -S "$work/td" -B "$work/android" \
  -DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_static \
  -DCMAKE_BUILD_TYPE=MinSizeRel -DOPENSSL_ROOT_DIR="$work/ssl" -DOPENSSL_USE_STATIC_LIBS=ON \
  -DCMAKE_SHARED_LINKER_FLAGS='-Wl,-z,max-page-size=16384' -DTD_GIT_COMMIT_HASH="$revision"
cmake --build "$work/android" --target tdjson --parallel "$jobs"
"$toolchain/llvm-strip" --strip-unneeded "$work/android/libtdjson.so"
python3 "$root/tool/check_android_16k.py" "$work/android/libtdjson.so"
mkdir -p "$output/arm64-v8a" "$output/../notices"
install -m 644 "$work/td/LICENSE_1_0.txt" "$output/../notices/TDLib-LICENSE.txt"
install -m 644 "$work/openssl/LICENSE.txt" "$output/../notices/OpenSSL-LICENSE.txt"
install -m 644 "$work/android/libtdjson.so" "$output/arm64-v8a/libtdjson.so.new"
mv -f "$output/arm64-v8a/libtdjson.so.new" "$output/arm64-v8a/libtdjson.so"
