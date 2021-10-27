function(fuzz_parser SpicyInput)
    get_filename_component(name ${SpicyInput} NAME_WLE)

    add_custom_command(
        OUTPUT "${name}.cc"
        COMMAND ${CMAKE_BINARY_DIR}/bin/spicyc -c -o "${name}.cc" "${SpicyInput}"
        DEPENDS spicyc
        )

    add_custom_command(
        OUTPUT "${name}_link.cc"
        COMMAND ${CMAKE_BINARY_DIR}/bin/spicyc -l -o "${name}_link.cc" "${SpicyInput}"
        DEPENDS spicyc
        )

    add_executable(fuzz-${name} fuzz.cc "${name}.cc" "${name}_link.cc")
    target_compile_options(fuzz-${name} PRIVATE -fsanitize=fuzzer-no-link)
    target_link_options(fuzz-${name} PRIVATE -fsanitize=fuzzer-no-link)
    target_link_libraries(fuzz-${name} spicy-rt hilti-rt "/usr/lib/llvm-12/lib/clang/12.0.1/lib/linux/libclang_rt.fuzzer_no_main-x86_64.a")
endfunction()

fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/dhcp/dhcp.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/ipsec/ipsec.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/openvpn/openvpn.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/wireguard/wireguard.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/tftp/tftp.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/pe/pe.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/png/PNG.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/dns/dns.spicy)
fuzz_parser(${CMAKE_SOURCE_DIR}/zeek/spicy-analyzers/analyzer/http/http.spicy)
