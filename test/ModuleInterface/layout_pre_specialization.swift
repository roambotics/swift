// RUN: %empty-directory(%t)

// RUN: %target-swift-emit-module-interface(%t/LayoutPrespec.swiftinterface) %s -enable-experimental-feature LayoutPrespecialization -module-name LayoutPrespec -disable-availability-checking
// RUN: %target-swift-typecheck-module-from-interface(%t/LayoutPrespec.swiftinterface) -module-name LayoutPrespec -disable-availability-checking
// RUN: %target-swift-typecheck-module-from-interface(%t/LayoutPrespec.swiftinterface) -module-name LayoutPrespec -enable-experimental-feature LayoutPrespecialization -disable-availability-checking
// RUN: %FileCheck %s < %t/LayoutPrespec.swiftinterface

// CHECK: #if compiler(>=5.3) && $LayoutPrespecialization
// CHECK-NEXT: @_specialize(exported: true, kind: full, where @_noMetadata A : _Class)
// CHECK-NEXT: public func test<A>(a: A) -> A
// CHECK-NEXT: #endif
@_specialize(exported: true, where @_noMetadata A : _Class)
public func test<A>(a: A) -> A {
    return a
}
