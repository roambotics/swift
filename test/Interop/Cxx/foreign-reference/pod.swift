// RUN: %target-run-simple-swift(-I %S/Inputs/ -Xfrontend -enable-cxx-interop -Xfrontend -validate-tbd-against-ir=none -Xfrontend -disable-llvm-verify -g)
//
// REQUIRES: executable_test

import StdlibUnittest
import POD

//  TODO: Waiting on foreign reference type metadata implementation.
//
//  struct StructHoldingPair {
//    var pair: IntPair
//  };
//
//  class ClassHoldingPair {
//    var pair: IntPair
//
//    init(pair: IntPair) { self.pair = pair }
//  };

var globalPair: IntPair? = nil

var PODTestSuite = TestSuite("Plain old data types that are marked as foreign references")

PODTestSuite.test("Empty") {
  var x = Empty.create()
  expectEqual(x.test(), 42)
  expectEqual(x.testMutable(), 42)

  mutateIt(x)

  x = Empty.create()
  expectEqual(x.test(), 42)
}

PODTestSuite.test("var IntPair") {
  var x = IntPair.create()
  expectEqual(x.test(), 1)
  expectEqual(x.testMutable(), 1)

  mutateIt(x)
  expectEqual(x.test(), 2)
  expectEqual(x.testMutable(), 2)

  x.b = 42
  expectEqual(x.test(), 40)
  expectEqual(x.testMutable(), 40)

  x = IntPair.create()
  expectEqual(x.test(), 1)
}

PODTestSuite.test("let IntPair") {
  let x = IntPair.create()
  expectEqual(x.test(), 1)
  expectEqual(x.testMutable(), 1)

  mutateIt(x)
  expectEqual(x.test(), 2)
  expectEqual(x.testMutable(), 2)

  x.b = 42
  expectEqual(x.test(), 40)
  expectEqual(x.testMutable(), 40)
}

PODTestSuite.test("global") {
  globalPair = IntPair.create()
  expectEqual(globalPair!.test(), 1)
  expectEqual(globalPair!.testMutable(), 1)

  mutateIt(globalPair!)
  expectEqual(globalPair!.test(), 2)
  expectEqual(globalPair!.testMutable(), 2)

  globalPair!.b = 42
  expectEqual(globalPair!.test(), 40)
  expectEqual(globalPair!.testMutable(), 40)

  globalPair = IntPair.create()
  expectEqual(globalPair!.test(), 1)
}

PODTestSuite.test("RefHoldingPairRef") {
  var x = RefHoldingPairRef.create()
  expectEqual(x.test(), 41)
  expectEqual(x.testMutable(), 41)

  x.pair.b = 42
  expectEqual(x.test(), 1)
  expectEqual(x.testMutable(), 1)

  x = RefHoldingPairRef.create()
  expectEqual(x.test(), 41)
}

PODTestSuite.test("RefHoldingPairPtr") {
  var x = RefHoldingPairPtr.create()
  expectEqual(x.test(), 41)
  expectEqual(x.testMutable(), 41)

  x.pair.b = 42
  expectEqual(x.test(), 1)
  expectEqual(x.testMutable(), 1)

  x = RefHoldingPairPtr.create()
  expectEqual(x.test(), 41)
}

//  TODO: Waiting on foreign reference types metadata implementation.
//
//  PODTestSuite.test("StructHoldingPair") {
//   var x = StructHoldingPair(pair: IntPair.create())
//   expectEqual(x.pair.test(), 1)
//   expectEqual(x.pair.testMutable(), 1)
//
//   mutateIt(x.pair)
//   expectEqual(x.pair.test(), 2)
//   expectEqual(x.pair.testMutable(), 2)
//
//   x.pair = IntPair.create()
//   expectEqual(x.pair.test(), 1)
//  }
//
//  PODTestSuite.test("ClassHoldingPair") {
//    var x = ClassHoldingPair(pair: IntPair.create())
//    expectEqual(x.pair.test(), 1)
//    expectEqual(x.pair.testMutable(), 1)
//
//    mutateIt(x.pair)
//    expectEqual(x.pair.test(), 2)
//    expectEqual(x.pair.testMutable(), 2)
//
//    x.pair = IntPair.create()
//    expectEqual(x.pair.test(), 1)
//  }

PODTestSuite.test("BigType") {
  var x = BigType.create()
  expectEqual(x.test(), 1)
  expectEqual(x.testMutable(), 1)

  mutateIt(x)
  expectEqual(x.test(), 2)
  expectEqual(x.testMutable(), 2)

  x.b = 42
  expectEqual(x.test(), 40)
  expectEqual(x.testMutable(), 40)

  x = BigType.create()
  expectEqual(x.test(), 1)
}

runAllTests()
