#!/usr/bin/env python3

import multiprocessing
import os
import shutil
import subprocess


IMAGE = "spicy-fuzz"
OUT = os.getcwd() + "/spicy-fuzz"

MAX_TOTAL_TIME = 600

def update_sources(uri: str, dest: str):
    if not os.path.isdir(dest):
        subprocess.check_call(["git", "clone", "--recursive", uri, dest])
    else:
        subprocess.check_call(["git", "pull"], cwd=dest)
        subprocess.check_call(["git", "submodule", "update", "--recursive", "--init"], cwd=dest)

    subprocess.call(["git", "reset", "HEAD", "--hard"], cwd=dest)

# Build base Docker image.
subprocess.check_call(["docker", "build", "-t", IMAGE, "."])

# Check out or update Spicy and spicy-analyzers sources.
update_sources("https://github.com/zeek/spicy", "spicy")
update_sources("https://github.com/zeek/spicy-analyzers", "spicy/zeek/spicy-analyzers")

# Update Spicy for fuzzing.
if not os.path.isdir("spicy/ci/fuzz"):
    os.mkdir("spicy/ci/fuzz")
for f in ["build.sh", "Dockerfile", "fuzz.cc", "run.py", "CMakeLists.txt"]:
    shutil.copy(f, "spicy/ci/fuzz/%s" % f)

with open("spicy/CMakeLists.txt", "a") as cmakelists:
    cmakelists.write("add_subdirectory(ci/fuzz)")

# Create fuzzing binaries.
try:
    os.mkdir(OUT)
except FileExistsError:
    pass

subprocess.check_call(["docker", "run", "--rm",
                       "--privileged",
                       "-v", OUT+":/out", "-e", "OUT=/out",
                       "-v", os.getcwd() + "/spicy:/work",
                       "-e", "CXX=clang++-12",
                       "-e", "CC=clang-12",
                       "-e", "SANITIZER=address",
                       IMAGE,
                       "/work/ci/fuzz/build.sh",
                       ])

# Run individual fuzzers.
fuzzers = {
    "dhcp": ["Message"],
    "dns": ["Message"],
    "http": ["HTTP::Request", "HTTP::Requests", "HTTP::Reply", "HTTP::Replies"],
    "ipsec": ["IPSecPacketUDP", "IPSecPacketsTCP", "IPSecIKE"],
    "tftp": ["Packet"],
    "pe": ["ImageFile"],
    "PNG": ["File"],
    "wireguard": ["WireGuardPacket"],
}

for grammar, parsers in fuzzers.items():
    for parser in parsers:
        subprocess.check_call(["docker", "run", "--rm",
                               "-v", OUT + ":/work",
                               "-e", "SPICY_FUZZ_PARSER=" + parser,
                               "-e", "ASAN_OPTIONS=detect_leaks=0",
                               IMAGE,
                               *"/work/fuzz-{grammar} -timeout=120 -max_total_time={max_total_time} -jobs={nproc} -create_missing_dirs=1 -artifact_prefix=/work/corpus-fuzz-{grammar}-{parser}/artifacts/ /work/corpus-fuzz-{grammar}-{parser}".format(
                                   grammar=grammar,
                                   parser=parser,
                                   max_total_time=MAX_TOTAL_TIME,
                                   nproc=multiprocessing.cpu_count()).split(),
                               ])
