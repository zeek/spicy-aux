#!/bin/sh

# This script runs the upstream benchmarks and produces a file
# $SPICY_BENCHMARK_DIR/report.txt.
#
# All dependencies are cached and kept up to date in $SPICY_BENCHMARK_DIR.

set -e

exec 2>&1

BASEDIR=$(cd "$(dirname "$0")" && pwd)

# Settings. {{{
# This variable specifies the location where benchmarking artifacts are cached.
export SPICY_BENCHMARK_DIR=$HOME/spicy-benchmark

export CXX=/opt/clang10/bin/clang++
export CC=/opt/clang10/bin/clang
export ASM=${CC}

SPICY_BENCHMARK_DATA=spicy-benchmark-m57.tar.xz
SPICY_BENCHMARK_DATA_DIR=${SPICY_BENCHMARK_DIR}/$(basename ${SPICY_BENCHMARK_DATA} .tar.xz)
export PREFIX=${SPICY_BENCHMARK_DIR}/prefix
export PATH=${ZEEK_PREFIX:-/data/zeek-4.0.1}/bin:$PATH
export PATH=${PREFIX}/bin:$PATH
export ZEEK_PLUGIN_PATH=$PREFIX/lib64/spicy
# }}}

# Get sources. {{{

# Update Spicy sources. {{{
echo "Updating Spicy sources"
if [ ! -d "${SPICY_BENCHMARK_DIR}/spicy" ]; then
	git clone https://github.com/zeek/spicy --recursive "${SPICY_BENCHMARK_DIR}"/spicy
fi
(
	cd "${SPICY_BENCHMARK_DIR}"/spicy || exit
	git pull
	git submodule update --init --recursive
)
# }}}

# Update spicy-plugin sources. {{{
echo "Updating spicy-plugin sources"
if [ ! -d "${SPICY_BENCHMARK_DIR}"/spicy-plugin ]; then
	git clone https://github.com/zeek/spicy-plugin --recursive "${SPICY_BENCHMARK_DIR}"/spicy-plugin
fi
(
	cd "${SPICY_BENCHMARK_DIR}"/spicy-plugin || exit
	git pull
	git submodule update --init --recursive
)
# }}}

# Update spicy-analyzers sources. {{{
echo "Updating spicy-analyzers sources"
if [ ! -d "${SPICY_BENCHMARK_DIR}"/spicy-analyzers ]; then
	git clone https://github.com/zeek/spicy-analyzers --recursive "${SPICY_BENCHMARK_DIR}"/spicy-analyzers
fi
(
	cd "${SPICY_BENCHMARK_DIR}"/spicy-analyzers || exit
	git pull
	git submodule update --init --recursive
)
# }}}

# Update benchmark inputs. {{{
echo "Updating benchmark inputs"
(
	cd "${SPICY_BENCHMARK_DIR}"
	curl --silent --show-error -L --remote-name-all -z "${SPICY_BENCHMARK_DATA}" https://download.zeek.org/data/"${SPICY_BENCHMARK_DATA}"
	rm -rf "${SPICY_BENCHMARK_DATA_DIR}"
	tar xf "${SPICY_BENCHMARK_DATA}" -C "${SPICY_BENCHMARK_DIR}"
)
# }}}

# }}}

# Build binaries. {{{

rm -rf "${PREFIX}"

# Build Spicy. {{{
echo "Building Spicy"
(
	cd "${SPICY_BENCHMARK_DIR}"/spicy
	rm -rf build
	./configure --enable-ccache --with-zeek="${ZEEK_PREFIX:-/data/zeek-4.0.1}" --build-type=Release --generator=Ninja --prefix="${PREFIX}"
	ninja -C build install
)
# }}}

# Build spicy-plugin. {{{
echo "Building spicy-plugin"
(
	cd "${SPICY_BENCHMARK_DIR}"/spicy-plugin
	rm -rf build && mkdir -p build
	cd build || exit
	cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release -DZEEK_ROOT_DIR="${ZEEK_PREFIX:-/data/zeek-4.0.1}" -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_INSTALL_PREFIX="${PREFIX}"
	ninja install
)
# }}}

# }}}

# Build benchmark. {{{
echo "Building benchmark"
(
	cd "${SPICY_BENCHMARK_DIR}"
	"${BASEDIR}"/benchmark-wrapper build
)
# }}}

# }}}

# Run benchmarks. {{{
echo "Running benchmarks"
(
	cd "${SPICY_BENCHMARK_DIR}"
	for benchmark in short long; do
		"${BASEDIR}"/benchmark-wrapper -t "${SPICY_BENCHMARK_DATA_DIR}"/$benchmark run | tee "${SPICY_BENCHMARK_DIR}"/$benchmark.log
	done
	"${SPICY_BENCHMARK_DIR}"/spicy/build/bin/hilti-rt-fiber-benchmark | tee "${SPICY_BENCHMARK_DIR}"/fiber.log
)
# }}}

# Generate report. {{{
echo "Generating benchmark report"
SPICY_BENCHMARK_REPORT=${SPICY_BENCHMARK_DIR}/report.txt
rm -f "${SPICY_BENCHMARK_REPORT}"
(
	echo "Version: $(spicy-config --version)"
	echo "Date: $(date)"
	for benchmark in short long fiber; do
		echo ""
		echo "Benchmark: $benchmark"
		echo "---------------------"
		cat "${SPICY_BENCHMARK_DIR}"/$benchmark.log
	done
) >"${SPICY_BENCHMARK_REPORT}"
# }}}

# vim: fdm=marker
