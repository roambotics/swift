//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Swift
import _SwiftRuntimeShims

@available(SwiftStdlib 5.9, *)
@frozen
public struct BoxPair {
  public typealias Storage = (
    object: HeapObject,
    buffer: UnsafeMutableRawPointer
  )
  
  @usableFromInline
  let storage: Storage
  
  @inlinable
  public var object: HeapObject {
    storage.object
  }
  
  @inlinable
  public var buffer: UnsafeMutableRawPointer {
    storage.buffer
  }
}

@available(SwiftStdlib 5.9, *)
@_silgen_name("swift_allocBox")
public func swift_allocBox(_: Metadata) -> BoxPair

@available(SwiftStdlib 5.9, *)
@_silgen_name("_swift_class_isSubclass")
internal func _isSubclass(_: Metadata, _: Metadata) -> Bool

@available(SwiftStdlib 5.9, *)
@inlinable
public func swift_conformsToProtocol(
  _ type: Metadata,
  _ protocol: ProtocolDescriptor
) -> WitnessTable? {
  guard let wt = swift_conformsToProtocol(type.ptr, `protocol`.ptr) else {
    return nil
  }
  
  return WitnessTable(wt)
}

@available(SwiftStdlib 5.9, *)
@inlinable
public func swift_projectBox(
  _ obj: HeapObject
) -> UnsafeMutableRawPointer {
  swift_projectBox(obj.ptr.mutable)
}
