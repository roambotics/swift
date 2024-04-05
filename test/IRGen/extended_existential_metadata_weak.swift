// RUN: %target-swift-frontend -emit-ir %s -target %target-swift-abi-5.5-triple | %FileCheck %s
// REQUIRES: VENDOR=apple

public protocol P<A> {
  associatedtype A
}

public func f<T>(_: T.Type) {}

@available(SwiftStdlib 5.7, *)
public func g<T>(_: T.Type) { f((any P<T>).self) }

// CHECK-LABEL: declare extern_weak ptr @swift_getExtendedExistentialTypeMetadata(ptr, ptr)