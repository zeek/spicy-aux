#!/bin/sh

set -eu

/work/configure --enable-debug --enable-sanitizer="${SANITIZER}" --generator=Ninja
ninja -C build ci/fuzz/all
cp build/bin/fuzz-* "${OUT}"
