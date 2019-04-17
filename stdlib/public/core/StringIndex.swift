//===--- StringIndex.swift ------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftShims

/*

String's Index has the following layout:

 ┌──────────┬───────────────────┬────────────────┬──────────┐
 │ b63:b16  │      b15:b14      │     b13:b8     │ b7:b0    │
 ├──────────┼───────────────────┼────────────────┼──────────┤
 │ position │ transcoded offset │ grapheme cache │ reserved │
 └──────────┴───────────────────┴────────────────┴──────────┘

- grapheme cache: A 6-bit value remembering the distance to the next grapheme
boundary
- position aka `encodedOffset`: An offset into the string's code units
- transcoded offset: a sub-scalar offset, derived from transcoding

The use and interpretation of both `reserved` and `grapheme cache` is not part
of Index's ABI; it should be hidden behind non-inlinable calls. However, the
position of the sequence of 14 bits allocated is part of Index's ABI, as well as
the default value being `0`.

*/
extension String {
  /// A position of a character or code unit in a string.
  @_fixed_layout
  public struct Index {
    @usableFromInline
    internal var _rawBits: UInt64

    @inlinable @inline(__always)
    init(_ raw: UInt64) {
      self._rawBits = raw
      self._invariantCheck()
    }
  }
}

extension String.Index {
  @inlinable @inline(__always)
  internal var orderingValue: UInt64 { return _rawBits &>> 14 }

  // Whether this is at the canonical "start" position, that is encoded AND
  // transcoded offset of 0.
  @inlinable @inline(__always)
  internal var isZeroPosition: Bool { return orderingValue == 0 }

  /// The UTF-16 code unit offset corresponding to this Index
  public func utf16Offset<S: StringProtocol>(in s: S) -> Int {
    return s.utf16.distance(from: s.utf16.startIndex, to: self)
  }

  /// The offset into a string's code units for this index.
  @available(swift, deprecated: 4.2, message: """
    encodedOffset has been deprecated as most common usage is incorrect. \
    Use utf16Offset(in:) to achieve the same behavior.
    """)
  @inlinable
  public var encodedOffset: Int { return _encodedOffset }

  @inlinable @inline(__always)
  internal var _encodedOffset: Int {
    return Int(truncatingIfNeeded: _rawBits &>> 16)
  }

  @inlinable @inline(__always)
  internal var transcodedOffset: Int {
    return Int(truncatingIfNeeded: orderingValue & 0x3)
  }

  @usableFromInline
  internal var characterStride: Int? {
    let value = (_rawBits & 0x3F00) &>> 8
    return value > 0 ? Int(truncatingIfNeeded: value) : nil
  }

  @inlinable @inline(__always)
  internal init(encodedOffset: Int, transcodedOffset: Int) {
    let pos = UInt64(truncatingIfNeeded: encodedOffset)
    let trans = UInt64(truncatingIfNeeded: transcodedOffset)
    _internalInvariant(pos == pos & 0x0000_FFFF_FFFF_FFFF)
    _internalInvariant(trans <= 3)

    self.init((pos &<< 16) | (trans &<< 14))
  }

  /// Creates a new index at the specified UTF-16 code unit offset
  ///
  /// - Parameter offset: An offset in UTF-16 code units.
  public init<S: StringProtocol>(utf16Offset offset: Int, in s: S) {
    let (start, end) = (s.utf16.startIndex, s.utf16.endIndex)
    guard offset >= 0,
          let idx = s.utf16.index(start, offsetBy: offset, limitedBy: end)
    else {
      self = end.nextEncoded
      return
    }
    self = idx
  }

  /// Creates a new index at the specified code unit offset.
  ///
  /// - Parameter offset: An offset in code units.
  @available(swift, deprecated: 4.2, message: """
    encodedOffset has been deprecated as most common usage is incorrect. \
    Use String.Index(utf16Offset:in:) to achieve the same behavior.
    """)
  @inlinable
  public init(encodedOffset offset: Int) {
    self.init(_encodedOffset: offset)
  }

  @inlinable @inline(__always)
  internal init(_encodedOffset offset: Int) {
    self.init(encodedOffset: offset, transcodedOffset: 0)
  }

  @usableFromInline
  internal init(
    encodedOffset: Int, transcodedOffset: Int, characterStride: Int
  ) {
    self.init(encodedOffset: encodedOffset, transcodedOffset: transcodedOffset)
    if _slowPath(characterStride > 63) { return }

    _internalInvariant(characterStride == characterStride & 0x3F)
    self._rawBits |= UInt64(truncatingIfNeeded: characterStride &<< 8)
    self._invariantCheck()
  }

  @usableFromInline
  internal init(encodedOffset pos: Int, characterStride char: Int) {
    self.init(encodedOffset: pos, transcodedOffset: 0, characterStride: char)
  }

  #if !INTERNAL_CHECKS_ENABLED
  @inlinable @inline(__always) internal func _invariantCheck() {}
  #else
  @usableFromInline @inline(never) @_effects(releasenone)
  internal func _invariantCheck() {
    _internalInvariant(_encodedOffset >= 0)
  }
  #endif // INTERNAL_CHECKS_ENABLED
}

// Creation helpers, which will make migration easier if we decide to use and
// propagate the reserved bits.
extension String.Index {
  @inlinable @inline(__always)
  internal var strippingTranscoding: String.Index {
    return String.Index(_encodedOffset: self._encodedOffset)
  }

  @inlinable @inline(__always)
  internal var nextEncoded: String.Index {
    _internalInvariant(self.transcodedOffset == 0)
    return String.Index(_encodedOffset: self._encodedOffset &+ 1)
  }

  @inlinable @inline(__always)
  internal var priorEncoded: String.Index {
    _internalInvariant(self.transcodedOffset == 0)
    return String.Index(_encodedOffset: self._encodedOffset &- 1)
  }

  @inlinable @inline(__always)
  internal var nextTranscoded: String.Index {
    return String.Index(
      encodedOffset: self._encodedOffset,
      transcodedOffset: self.transcodedOffset &+ 1)
  }

  @inlinable @inline(__always)
  internal var priorTranscoded: String.Index {
    return String.Index(
      encodedOffset: self._encodedOffset,
      transcodedOffset: self.transcodedOffset &- 1)
  }

  // Get an index with an encoded offset relative to this one.
  // Note: strips any transcoded offset.
  @inlinable @inline(__always)
  internal func encoded(offsetBy n: Int) -> String.Index {
    return String.Index(_encodedOffset: self._encodedOffset &+ n)
  }

  @inlinable @inline(__always)
  internal func transcoded(withOffset n: Int) -> String.Index {
    _internalInvariant(self.transcodedOffset == 0)
    return String.Index(encodedOffset: self._encodedOffset, transcodedOffset: n)
  }

}

extension String.Index: Equatable {
  @inlinable @inline(__always)
  public static func == (lhs: String.Index, rhs: String.Index) -> Bool {
    return lhs.orderingValue == rhs.orderingValue
  }
}

extension String.Index: Comparable {
  @inlinable @inline(__always)
  public static func < (lhs: String.Index, rhs: String.Index) -> Bool {
    return lhs.orderingValue < rhs.orderingValue
  }
}

extension String.Index: Hashable {
  /// Hashes the essential components of this value by feeding them into the
  /// given hasher.
  ///
  /// - Parameter hasher: The hasher to use when combining the components
  ///   of this instance.
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(orderingValue)
  }
}
