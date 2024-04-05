// RUN: %target-swift-emit-ir %s -target %target-cpu-apple-macos14 -enable-experimental-feature Embedded | %FileCheck %s

// REQUIRES: swift_in_compiler
// REQUIRES: VENDOR=apple
// REQUIRES: OS=macosx

protocol Proto { }

struct MyStruct: Proto { }

func foo() -> some Proto {
  MyStruct()
}

// CHECK: define {{.*}}@main(
