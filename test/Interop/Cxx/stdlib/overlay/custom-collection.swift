// RUN: %target-run-simple-swift(-I %S/Inputs -Xfrontend -enable-experimental-cxx-interop)
//
// REQUIRES: executable_test
// REQUIRES: OS=macosx || OS=linux-gnu

import StdlibUnittest
import CustomSequence
import Cxx

var CxxCollectionTestSuite = TestSuite("CxxCollection")

CxxCollectionTestSuite.test("SimpleCollectionNoSubscript as Swift.Collection") {
  let c = SimpleCollectionNoSubscript()
  expectEqual(c.first, 1)
  expectEqual(c.last, 5)

  // This subscript is a default implementation added in CxxRandomAccessCollection.
  expectEqual(c[0], 1)
  expectEqual(c[1], 2)
  expectEqual(c[4], 5)
}

CxxCollectionTestSuite.test("SimpleCollectionReadOnly as Swift.Collection") {
  let c = SimpleCollectionReadOnly()
  expectEqual(c.first, 1)
  expectEqual(c.last, 5)

  let slice = c[1..<3]
  expectEqual(slice.first, 2)
  expectEqual(slice.last, 3)
}

CxxCollectionTestSuite.test("SimpleArrayWrapper as Swift.Collection") {
  let c = SimpleArrayWrapper()
  expectEqual(c.first, 10)
  expectEqual(c.last, 50)

  let reduced = c.reduce(0, +)
  expectEqual(reduced, 150)

  let mapped = c.map { $0 + 1 }
  expectEqual(mapped.first, 11)
  expectEqual(mapped.last, 51)
}

runAllTests()
