// RUN: %target-run-simple-swift(-I %S/Inputs -Xfrontend -enable-experimental-cxx-interop -Xfrontend -validate-tbd-against-ir=none)
//
// REQUIRES: executable_test
//
// Enable this everywhere once we have a solution for modularizing other C++ stdlibs: rdar://87654514
// REQUIRES: OS=macosx || OS=linux-gnu

import StdlibUnittest
import StdSet
import CxxStdlib
import Cxx

var StdSetTestSuite = TestSuite("StdSet")

StdSetTestSuite.test("iterate over Swift.Array") {
    let s = Array(initSetOfCInt())
    var result = [CInt]()
    for x in s {
        result.append(x)
    }
    expectEqual(result[0], 1)
    expectEqual(result[1], 3)
    expectEqual(result[2], 5)
}

StdSetTestSuite.test("SetOfCInt.contains") {
    // This relies on the `std::set` conformance to `CxxSet` protocol.
    let s = initSetOfCInt()
    expectTrue(s.contains(1))
    expectFalse(s.contains(2))
    expectTrue(s.contains(3))
}

StdSetTestSuite.test("UnorderedSetOfCInt.contains") {
    // This relies on the `std::unordered_set` conformance to `CxxSet` protocol.
    let s = initUnorderedSetOfCInt()
    expectFalse(s.contains(1))
    expectTrue(s.contains(2))
    expectFalse(s.contains(3))
}

StdSetTestSuite.test("MultisetOfCInt.contains") {
    // This relies on the `std::multiset` conformance to `CxxSet` protocol.
    let s = initMultisetOfCInt()
    expectFalse(s.contains(1))
    expectTrue(s.contains(2))
    expectFalse(s.contains(3))
}

runAllTests()
