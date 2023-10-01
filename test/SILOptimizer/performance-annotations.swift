// RUN: %target-swift-frontend -parse-as-library -emit-sil %s -o /dev/null -verify
// REQUIRES: swift_stdlib_no_asserts,optimized_stdlib
// REQUIRES: swift_in_compiler

protocol P {
  func protoMethod(_ a: Int) -> Int
}

open class Cl {
  open func classMethod() {}
  final func finalMethod() {}
}

func initFunc() -> Int { return Int.random(in: 0..<10) }

struct Str : P {
  let x: Int

  func protoMethod(_ a: Int) -> Int {
    return a + x
  }

  static let s = 27
  static var s2 = 10 + s
  static var s3 = initFunc() // expected-error {{global/static variable initialization can cause locking}}
}

struct AllocatingStr : P {
  func protoMethod(_ a: Int) -> Int {
    _ = Cl()                // expected-error {{Using type 'Cl' can cause metadata allocation or locks}} 
    return 0
  }
}

func noRTCallsForArrayGet(_ a: [Str], _ i: Int) -> Int {
  return a[i].x
}

@_noLocks
func callArrayGet(_ a: [Str]) -> Int {
  return noRTCallsForArrayGet(a, 0)
}

@_noLocks
func arcOperations(_ x: Cl) -> Cl {
  return x                // expected-error {{this code performs reference counting operations which can cause locking}} 
}

func genFunc<T: P>(_ t: T, _ a: Int) -> Int {
  let s = t
  return t.protoMethod(a) + s.protoMethod(a) // expected-note {{called from here}}
}

@_noAllocation
func callMethodGood(_ a: Int) -> Int {
  return genFunc(Str(x: 1), a)
}

@_noAllocation
func callMethodBad(_ a: Int) -> Int {
  return genFunc(AllocatingStr(), a) // expected-note {{called from here}}
}

@_noAllocation
func callClassMethod(_ c: Cl) {
  return c.classMethod() // expected-error {{called function is not known at compile time and can have unpredictable performance}}
}

@_noAllocation
func callFinalMethod(_ c: Cl) {
  return c.finalMethod()
}

@_noAllocation
func callProtocolMethod(_ p: P) -> Int {
  return p.protoMethod(0) // expected-error {{this code pattern can cause metadata allocation or locks}}
}

@_noAllocation
func dynamicCast(_ a: AnyObject) -> Cl? {
  return a as? Cl // expected-error {{dynamic casting can lock or allocate}}
}

@_noAllocation
func testUnsafePerformance(_ idx: Int) -> [Int] {
  return _unsafePerformance { [10, 20, 30, 40] }
}

@_noAllocation
func testMemoryLayout() -> Int {
  return MemoryLayout<Int>.size + MemoryLayout<Int>.stride + MemoryLayout<Int>.alignment
}

class MyError : Error {}

@_noLocks
func noDiagnosticsInThrowPath(_ b: Bool) throws -> Int {
  if b {
    return 28
  }
  throw MyError()
}

@_noLocks
func noDiagnosticsInCatch(_ b: Bool) throws -> Int? {
  do {
    return try noDiagnosticsInThrowPath(true)
  } catch let e as MyError {
    print(e)
    return nil
  }
}

@_noLocks
func testRecursion(_ i: Int) -> Int {
  if i > 0 {
    return testRecursion(i - 1)
  }
  return 0
}

@_noLocks
func testGlobal() -> Int {
  return Str.s + Str.s2
}

@_noLocks
func testGlobalWithComplexInit() -> Int {
  return Str.s3 // expected-note {{called from here}}
}

func metatypeArg<T>(_ t: T.Type, _ b: Bool) {
}

@_noAllocation
func callFuncWithMetatypeArg() {
  metatypeArg(Int.self, false)
}

@_noAllocation
func intConversion() {
  let x = 42
  _ = UInt(x)
}

@_noAllocation
func integerRange() {
  for _ in 0 ..< 10 {
  }
}

struct GenStruct<A> {
  var a: A
}

@_noAllocation
func memoryLayout() -> Int? {
  return MemoryLayout<GenStruct<Int>>.size
}

class H {
  var hash: Int { 27 }
}

struct MyStruct {
  static var v: Int = {      // expected-error {{Using type 'H' can cause metadata allocation or locks}}
    return H().hash
  }()
}

@_noAllocation
func globalWithInitializer(x: MyStruct) {
  _ = MyStruct.v         // expected-note {{called from here}}
}

@_noAllocation
func callBadClosure(closure: ()->Int) -> Int {
  return closure()
}

@_noAllocation
func badClosure() {
  _ = callBadClosure(closure: { // expected-note {{called from here}}
     _ = Cl()                   // expected-error {{Using type 'Cl' can cause metadata allocation or locks}}
     return 42
    })
}

func badClosure2() {
  _ = callBadClosure(closure: { // expected-note {{called from here}}
     _ = Cl()                   // expected-error {{Using type 'Cl' can cause metadata allocation or locks}}
     return 42
    })
}

@_noAllocation
func callGoodClosure(closure: ()->Int) -> Int {
  return closure()
}

@_noAllocation
func goodClosure() {
  _ = callBadClosure(closure: {
     return 42
    })
}

func goodClosure2() {
  _ = callBadClosure(closure: {
     return 42
    })
}

@_noAllocation
func closueWhichModifiesLocalVar() -> Int {
  var x = 42
  let localNonEscapingClosure = {
    x += 1
  }
  localNonEscapingClosure()
  return x
}

@_noAllocation
func createEmptyArray() {
  _ = [Int]() // expected-error {{ending the lifetime of a value of type}}
}

struct Buffer {
  var p: UnsafeMutableRawBufferPointer

  func bind<T>(of type: T.Type) -> UnsafeMutableBufferPointer<T> {
    self.p.bindMemory(to: T.self)
  }

  @_noAllocation
  func callBind() -> UnsafeMutableBufferPointer<Int> {
    return bind(of: Int.self)
  }
}

@_noLocks
func testBitShift(_ x: Int) -> Int {
    return x << 1
}

@_noLocks
func testUintIntConversion() -> Int {
    let u: UInt32 = 5
    return Int(u)
}

struct OptSet: OptionSet {
    let rawValue: Int

    public static var a: OptSet { return OptSet(rawValue: 1) }
    public static var b: OptSet { return OptSet(rawValue: 2) }
    public static var c: OptSet { return OptSet(rawValue: 4) }
    public static var d: OptSet { return OptSet(rawValue: 8) }
}

@_noLocks
func testOptionSet(_ options: OptSet) -> Bool {
    return options.contains(.b)
}

let globalA = 0xff
let globalB = UInt32(globalA)

@_noLocks
func testGlobalsWithConversion() -> UInt32 {
    return globalB
}

public struct X: Collection {
    public func index(after i: Int) -> Int {
        return i + 1
    }
    public subscript(position: Int) -> Int {
        get {
            return 0
        }
    }
    public var startIndex: Int = 0
    public var endIndex: Int = 1
    public typealias Index = Int
}

extension Collection where Element: Comparable {
    public func testSorted() -> Int {
        return testSorted(by: <)
    }
    public func testSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> Int {
        let x = 0
        _ = areInIncreasingOrder(self.first!, self.first!)
        return x
    }
}
@_noLocks
public func testCollectionSort(a: X) -> Int {
    _ = a.testSorted()
    return 0
}

public struct Y {
  var a, b, c: Int
}

extension Y {
  func with2(_ body: () -> ()) {
    body()
  }
  
  func with1(_ body: (Int) -> (Int)) -> Int {
    with2 {
      _ = body(48)
    }
    return 777
  }
  
  func Xsort() -> Int {
    with1 { i in
      i
    }
  }
}

@_noLocks
public func testClosurePassing(a: inout Y) -> Int {
    return a.Xsort()
}

struct LargeGenericStruct<T> {
  var a: T
  var b: T
  var c: T
  var d: T
  var e: T
  var f: T
  var g: T
  var h: T
}

var largeGeneric = LargeGenericStruct<Int>(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8)

@_noLocks
func testLargeGenericStruct() -> LargeGenericStruct<Int> {
  return largeGeneric
}

struct ContainsLargeGenericStruct {
  var s: LargeGenericStruct<Int>
}

var clgs = ContainsLargeGenericStruct(s: LargeGenericStruct<Int>(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8))

@_noLocks
func testClgs() -> ContainsLargeGenericStruct {
  return clgs
}

struct NestedGenericStruct<T> {
  var a: T
  var b: T
  var c: LargeGenericStruct<T>
  var d: T
  var e: T
  var f: T
  var g: T
  var h: T
}

var nestedGeneric = NestedGenericStruct(a: 1, b: 2, c: LargeGenericStruct<Int>(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8), d: 4, e: 5, f: 6, g: 7, h: 8)

@_noLocks
func testNestedGenericStruct() -> NestedGenericStruct<Int> {
  return nestedGeneric
}

var x = 24
let pointerToX = UnsafePointer(&x)

@_noLocks
func testPointerToX() -> UnsafePointer<Int> {
  return pointerToX
}

func foo<T>(_ body: () -> (T)) -> T {
    return body()
}

func bar<T>(_ body: () -> (T)) -> T {
    return body()
}

func baz<T>(t: T) -> T {
    foo {
        bar {
            return t
        }
    }
}

@_noLocks
func nestedClosures() -> Int {
    return baz(t: 42)
}
