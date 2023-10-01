//===----------- Test.swift - In-IR tests from Swift source ---------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// TO ADD A NEW TEST, just add a new FunctionTest instance.
// - In the source file containing the functionality you want to test:
//       let myNewTest = 
//       FunctionTest("my_new_test") { function, arguments, context in
//       }
// - In SwiftCompilerSources/Sources/SIL/Test.swift's registerSILTests function,
//   register the new test:
//       registerFunctionTest(myNewTest, implementation: { myNewTest.run($0, $1, $2) })
//
//===----------------------------------------------------------------------===//
//
// Provides a mechanism for writing tests against compiler code in the context
// of a function.  The goal is to get the same effect as calling a function and
// checking its output.
//
// This is done via the specify_test instruction.  Using one or more instances
// of it in your test case's SIL function, you can specify which test (instance
// of FunctionTest) should be run and what arguments should be provided to it.
// The test grabs the arguments it expects out of the TestArguments instance
// it is provided.  It calls some function or functions.  It then prints out
// interesting results.  These results can then be FileCheck'd.
//
// CASE STUDY:
// Here's an example of how it works:
// 0) A source file, NeatUtils.cpp contains
//
//    fileprivate func myNeatoUtility(int: Int, value: Value, function: Function) { ... }
//
//    and
//
//    let myNeatoUtilityTest = 
//    FunctionTest("my_neato_utility") { function, arguments, test in
//         // The code here is described in detail below.
//         // See 4).
//         let count = arguments.takeInt()
//         let target = arguments.takeValue()
//         let callee = arguments.takeFunction()
//         // See 5)
//         myNeatoUtility(int: count, value: target, function: callee)
//         // See 6)
//         print(function)
//      }
// 1) A test test/SILOptimizer/interesting_functionality_unit.sil runs the
//    TestRunner pass:
//     // RUN: %target-sil-opt -test-runner %s -o /dev/null 2>&1 | %FileCheck %s
// 2) A function in interesting_functionality_unit.sil contains the
//    specify_test instruction.
//      sil @f : $() -> () {
//      ...
//      specify_test "my_neato_utility 43 %2 @function[other_fun]"
//      ...
//      }
// 3) TestRunner finds the FunctionTest instance myNeatoUtilityTest registered
//    under the name "my_neato_utility", and calls run() on it, passing the
//    passing first the function, last the FunctionTest instance, AND in the
//    middle, most importantly a TestArguments instance that contains
//
//      (43 : Int, someValue : Value, other_fun : Function)
//
// 4) myNeatoUtilityTest calls takeUInt(), takeValue(), and takeFunction() on
//    the test::Arguments instance.
//      let count = arguments.takeInt()
//      let target = arguments.takeValue()
//      let callee = arguments.takeFunction()
// 5) myNeatoUtilityTest calls myNeatoUtility, passing these values along.
//      myNeatoUtility(int: count, value: target, function: callee)
// 6) myNeatoUtilityTest then dumps out the current function, which was modified
//    in the process.
//      print(function)
// 7) The test file test/SILOptimizer/interesting_functionality_unit.sil matches
// the
//    expected contents of the modified function:
//    // CHECK-LABEL: sil @f
//    // CHECK-NOT:     function_ref @other_fun
//
//===----------------------------------------------------------------------===//

import Basic
import SILBridging

public struct FunctionTest {
  public var name: String
  public typealias FunctionTestImplementation = (Function, TestArguments, TestContext) -> ()
  private var implementation: FunctionTestImplementation
  init(name: String, implementation: @escaping FunctionTestImplementation) {
    self.name = name
    self.implementation = implementation
  }
  fileprivate func run(
    _ function: BridgedFunction, 
    _ arguments: BridgedTestArguments, 
    _ test: BridgedTestContext) {
    implementation(function.function, arguments.native, test.native)
  }
}

public struct TestArguments {
  public var bridged: BridgedTestArguments
  fileprivate init(bridged: BridgedTestArguments) {
    self.bridged = bridged
  }

  public var hasUntaken: Bool { bridged.hasUntaken() }
  public func takeString() -> StringRef { StringRef(bridged: bridged.takeString()) }
  public func takeBool() -> Bool { bridged.takeBool() }
  public func takeInt() -> Int { bridged.takeInt() }
  public func takeOperand() -> Operand { Operand(bridged: bridged.takeOperand()) }
  public func takeValue() -> Value { bridged.takeValue().value }
  public func takeInstruction() -> Instruction { bridged.takeInstruction().instruction }
  public func takeArgument() -> Argument { bridged.takeArgument().argument }
  public func takeBlock() -> BasicBlock { bridged.takeBlock().block }
  public func takeFunction() -> Function { bridged.takeFunction().function }
}

extension BridgedTestArguments {
  public var native: TestArguments { TestArguments(bridged: self) }
}

public struct TestContext {
  public var bridged: BridgedTestContext
  fileprivate init(bridged: BridgedTestContext) {
    self.bridged = bridged
  }
}

extension BridgedTestContext {
  public var native: TestContext { TestContext(bridged: self) }
}

private func registerFunctionTest(
  _ test: FunctionTest,
  implementation: BridgedFunctionTestThunk) {
  test.name._withStringRef { ref in
    registerFunctionTest(ref, implementation)
  }
}

public func registerSILTests() {
  registerFunctionTest(parseTestSpecificationTest, implementation: { parseTestSpecificationTest.run($0, $1, $2) })
}

// Arguments:
// - string: list of characters, each of which specifies subsequent arguments
//           - A: (block) argument
//           - F: function
//           - B: block
//           - I: instruction
//           - V: value
//           - O: operand
//           - b: boolean
//           - u: unsigned
//           - s: string
// - ...
// - an argument of the type specified in the initial string
// - ...
// Dumps:
// - for each argument (after the initial string)
//   - its type
//   - something to identify the instance (mostly this means calling dump)
let parseTestSpecificationTest = 
FunctionTest(name: "test_specification_parsing") { function, arguments, context in 
  struct _Stderr : TextOutputStream {
    public init() {}

    public mutating func write(_ string: String) {
      for c in string.utf8 {
        _swift_stdlib_putc_stderr(CInt(c))
      }
    }
  }
  var stderr = _Stderr()
  let expectedFields = arguments.takeString()
  for expectedField in expectedFields.string {
    switch expectedField {
    case "A":
      let argument = arguments.takeArgument()
      print("argument:\n\(argument)", to: &stderr)
    case "F":
      let function = arguments.takeFunction()
      print("function: \(function.name)", to: &stderr)
    case "B":
      let block = arguments.takeBlock()
      print("block:\n\(block)", to: &stderr)
    case "I":
      let instruction = arguments.takeInstruction()
      print("instruction: \(instruction)", to: &stderr)
    case "V":
      let value = arguments.takeValue()
      print("value: \(value)", to: &stderr)
    case "O":
      let operand = arguments.takeOperand()
      print("operand: \(operand)", to: &stderr)
    case "u":
      let u = arguments.takeInt()
      print("uint: \(u)", to: &stderr)
    case "b":
      let b = arguments.takeBool()
      print("bool: \(b)", to: &stderr)
    case "s":
      let s = arguments.takeString()
      print("string: \(s)", to: &stderr)
    default:
      fatalError("unknown field type was expected?!");
    }
  }
}

