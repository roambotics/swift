// RUN: %empty-directory(%t)
// RUN: split-file %s %t
// RUN: %swift-frontend -c %t/check.swift -parse-as-library -target wasm32-unknown-none-wasm \
// RUN:   -enable-experimental-feature Embedded -Xcc -fdeclspec -disable-stack-protector \
// RUN:   -o %t/check.o
// RUN: %clang -target wasm32-unknown-none-wasm %t/check.o %t/rt.c -nostdlib -o %t/check.wasm
// RUN: %target-run %t/check.wasm
// REQUIRES: executable_test
// REQUIRES: CPU=wasm32

//--- rt.c

#include <stddef.h>
#include <stdint.h>

void free(void *ptr) {}

int posix_memalign(void **memptr, size_t alignment, size_t size) {
    uintptr_t mem = __builtin_wasm_memory_grow(0, (size + 0xffff) / 0x10000);
    if (mem == -1) {
        return -1;
    }
    *memptr = (void *)(mem * 0x10000);
    *memptr = (void *)(((uintptr_t)*memptr + alignment - 1) & -alignment);
    return 0;
}

//--- check.swift

class Foo {}

@_cdecl("_start")
func main() {
  _ = Foo()
}
