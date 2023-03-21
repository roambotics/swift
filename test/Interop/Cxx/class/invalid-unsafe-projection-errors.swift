// RUN: rm -rf %t
// RUN: split-file %s %t
// RUN: not %target-swift-frontend -typecheck -I %t/Inputs  %t/test.swift  -enable-experimental-cxx-interop 2>&1 | %FileCheck %s

//--- Inputs/module.modulemap
module Test {
    header "test.h"
    requires cplusplus
}

//--- Inputs/test.h
struct Ptr { int *p; };
struct __attribute__((swift_attr("import_owned"))) StirngLiteral { const char *name; };

struct M {
        int *_Nonnull test1() const;
        int &test2() const;
        Ptr test3() const;

        int *begin() const;

        StirngLiteral stringLiteral() const { return StirngLiteral{"M"}; }
};

//--- test.swift

import Test

public func test(x: M) {
  // CHECK: note: C++ method 'test1' that returns a pointer of type 'UnsafeMutablePointer' is unavailable.
  // CHECK: note: C++ method 'test1' may return an interior pointer.
  // CHECK: note: Mark method 'test1' as 'SAFE_TO_IMPORT' in C++ to make it available in Swift.
  x.test1()
  // CHECK: note: C++ method 'test2' that returns a reference of type 'UnsafeMutablePointer' is unavailable.
  // CHECK: note: C++ method 'test2' may return an interior pointer.
  // CHECK: note: Mark method 'test2' as 'SAFE_TO_IMPORT' in C++ to make it available in Swift.
  x.test2()
  // CHECK: note: C++ method 'test3' that returns a value of type 'Ptr' is unavailable.
  // CHECK: note: C++ method 'test3' may return an interior pointer.
  // CHECK: note: Mark method 'test3' as 'SAFE_TO_IMPORT' in C++ to make it available in Swift.
  // CHECK: note: Mark type 'Ptr' as 'SELF_CONTAINED' in C++ to make methods that use it available in Swift.
  x.test3()
  // CHECK: note: C++ method 'begin' that returns an iterator is unavailable
  // CHECK: note: C++ methods that return iterators are potentially unsafe. Try re-writing to use Swift iterator APIs.
  x.begin()

  // CHECK-NOT: error: value of type 'M' has no member 'stringLiteral'
  x.stringLiteral()
}
