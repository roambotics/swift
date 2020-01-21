// RUN: %empty-directory(%t)
// RUN: %target-build-swift %s -module-name DefaultImplementationOf -emit-module -emit-module-path %t/
// RUN: %target-swift-symbolgraph-extract -module-name DefaultImplementationOf -I %t -pretty-print -o %t/DefaultImplementationOf.symbols.json
// RUN: %FileCheck %s --input-file %t/DefaultImplementationOf.symbols.json

public protocol P {
  var x: Int { get }
}

extension P {
  public var x: Int {
    return 2
  }
}  

// CHECK: "kind": "defaultImplementationOf",
// CHECK-NEXT: "source": "s:23DefaultImplementationOf1PPAAE1xSivp",
// CHECK-NEXT: "target": "s:23DefaultImplementationOf1PP1xSivp"
