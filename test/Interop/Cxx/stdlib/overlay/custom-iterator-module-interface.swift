// RUN: %target-swift-ide-test -print-module -module-to-print=CustomSequence -source-filename=x -I %S/Inputs -enable-experimental-cxx-interop -module-cache-path %t | %FileCheck %s

// CHECK: struct ConstIterator : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> ConstIterator
// CHECK:   static func == (lhs: ConstIterator, other: ConstIterator) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK: }

// CHECK: struct ConstRACIterator : UnsafeCxxRandomAccessIterator, UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> ConstRACIterator
// CHECK:   static func += (lhs: inout ConstRACIterator, v: ConstRACIterator.difference_type)
// CHECK:   static func - (lhs: ConstRACIterator, other: ConstRACIterator) -> Int32
// CHECK:   static func == (lhs: ConstRACIterator, other: ConstRACIterator) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK:   typealias Distance = Int32
// CHECK: }

// CHECK: struct ConstRACIteratorRefPlusEq : UnsafeCxxRandomAccessIterator, UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> ConstRACIterator
// CHECK:   static func += (lhs: inout ConstRACIteratorRefPlusEq, v: ConstRACIteratorRefPlusEq.difference_type)
// CHECK:   static func - (lhs: ConstRACIteratorRefPlusEq, other: ConstRACIteratorRefPlusEq) -> Int32
// CHECK:   static func == (lhs: ConstRACIteratorRefPlusEq, other: ConstRACIteratorRefPlusEq) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK:   typealias Distance = Int32
// CHECK: }

// CHECK: struct ConstIteratorOutOfLineEq : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> ConstIteratorOutOfLineEq
// CHECK: }
// CHECK: func == (lhs: ConstIteratorOutOfLineEq, rhs: ConstIteratorOutOfLineEq) -> Bool

// CHECK: struct MinimalIterator : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> MinimalIterator
// CHECK:   static func == (lhs: MinimalIterator, other: MinimalIterator) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK: }

// CHECK: struct ForwardIterator : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> ForwardIterator
// CHECK:   static func == (lhs: ForwardIterator, other: ForwardIterator) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK: }

// CHECK: struct HasCustomIteratorTag : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> HasCustomIteratorTag
// CHECK:   static func == (lhs: HasCustomIteratorTag, other: HasCustomIteratorTag) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK: }

// CHECK: struct HasCustomRACIteratorTag : UnsafeCxxRandomAccessIterator, UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> HasCustomRACIteratorTag
// CHECK:   static func += (lhs: inout HasCustomRACIteratorTag, x: Int32)
// CHECK:   static func - (lhs: HasCustomRACIteratorTag, x: HasCustomRACIteratorTag) -> Int32
// CHECK:   static func == (lhs: HasCustomRACIteratorTag, other: HasCustomRACIteratorTag) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK:   typealias Distance = Int32
// CHECK: }

// CHECK: struct HasCustomIteratorTagInline : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> HasCustomIteratorTagInline
// CHECK:   static func == (lhs: HasCustomIteratorTagInline, other: HasCustomIteratorTagInline) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK: }

// CHECK: struct HasTypedefIteratorTag : UnsafeCxxInputIterator {
// CHECK:   var pointee: Int32 { get }
// CHECK:   func successor() -> HasTypedefIteratorTag
// CHECK:   static func == (lhs: HasTypedefIteratorTag, other: HasTypedefIteratorTag) -> Bool
// CHECK:   typealias Pointee = Int32
// CHECK: }

// CHECK-NOT: struct HasNoIteratorCategory : UnsafeCxxInputIterator
// CHECK-NOT: struct HasInvalidIteratorCategory : UnsafeCxxInputIterator
// CHECK-NOT: struct HasNoEqualEqual : UnsafeCxxInputIterator
// CHECK-NOT: struct HasInvalidEqualEqual : UnsafeCxxInputIterator
// CHECK-NOT: struct HasNoIncrementOperator : UnsafeCxxInputIterator
// CHECK-NOT: struct HasNoPreIncrementOperator : UnsafeCxxInputIterator
// CHECK-NOT: struct HasNoDereferenceOperator : UnsafeCxxInputIterator
