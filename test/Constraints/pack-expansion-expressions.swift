// RUN: %target-typecheck-verify-swift -enable-experimental-feature VariadicGenerics

// REQUIRES: asserts

func tuplify<each T>(_ t: repeat each T) -> (repeat each T) {
  return (repeat each t)
}

func prepend<First, each Rest>(value: First, to rest: repeat each Rest) -> (First, repeat each Rest) {
  return (value, repeat each rest)
}

func concatenate<each T, each U>(_ first: repeat each T, with second: repeat each U) -> (repeat each T, repeat each U) {
  return (repeat each first, repeat each second)
}

func zip<each T, each U>(_ first: repeat each T, with second: repeat each U) -> (repeat (each T, each U)) {
  return (repeat (each first, each second))
}

func forward<each U>(_ u: repeat each U) -> (repeat each U) {
  return tuplify(repeat each u)
}

func forwardAndMap<each U, each V>(us u: repeat each U, vs v: repeat each V) -> (repeat [(each U, each V)]) {
  return tuplify(repeat [(each u, each v)])
}

func variadicMap<each T, each Result>(_ t: repeat each T, transform: repeat (each T) -> each Result) -> (repeat each Result) {
  return (repeat (each transform)(each t))
}

func coerceExpansion<each T>(_ value: repeat each T) {
  func promoteToOptional<each Wrapped>(_: repeat (each Wrapped)?) {}

  promoteToOptional(repeat each value)
}

func localValuePack<each T>(_ t: repeat each T) -> (repeat each T, repeat each T) {
  let local = repeat each t
  let localAnnotated: repeat each T = repeat each t

  return (repeat each local, repeat each localAnnotated)
}

protocol P {
  associatedtype A

  var value: A { get }

  func f(_ self: Self) -> Self
}

func outerArchetype<each T, U>(t: repeat each T, u: U) where each T: P {
  let _: repeat (each T.A, U) = repeat ((each t).value, u)
}

func sameElement<each T, U>(t: repeat each T, u: U) where each T: P, each T == U {
// expected-error@-1{{same-element requirements are not yet supported}}

  // FIXME: Opened element archetypes in diagnostics
  let _: repeat each T = repeat (each t).f(u)
  // expected-error@-1 {{cannot convert value of type 'U' to expected argument type 'τ_1_0'}}
}

func forEachEach<each C, U>(c: repeat each C, function: (U) -> Void)
    where each C: Collection, each C.Element == U {
    // expected-error@-1{{same-element requirements are not yet supported}}

  // FIXME: Opened element archetypes in diagnostics
  _ = repeat (each c).forEach(function)
  // expected-error@-1 {{cannot convert value of type '(U) -> Void' to expected argument type '(τ_1_0.Element) throws -> Void'}}
}

func typeReprPacks<each T>(_ t: repeat each T) where each T: ExpressibleByIntegerLiteral {
  _ = repeat Array<each T>()
  _ = repeat 1 as each T

  _ = Array<each T>() // expected-error {{pack reference 'T' can only appear in pack expansion or generic requirement}}
  _ = 1 as each T // expected-error {{pack reference 'T' can only appear in pack expansion or generic requirement}}
  repeat Invalid<String, each T>("") // expected-error {{cannot find 'Invalid' in scope}}
}

func sameShapeDiagnostics<each T, each U>(t: repeat each T, u: repeat each U) {
  _ = repeat (each t, each u) // expected-error {{pack expansion requires that 'U' and 'T' have the same shape}}
  _ = repeat Array<(each T, each U)>() // expected-error {{pack expansion requires that 'U' and 'T' have the same shape}}
  _ = repeat (Array<each T>(), each u) // expected-error {{pack expansion requires that 'U' and 'T' have the same shape}}
}

func returnPackExpansionType<each T>(_ t: repeat each T) -> repeat each T { // expected-error {{pack expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}
  fatalError()
}

func returnEachPackReference<each T>(_ t: repeat each T) -> each T { // expected-error {{pack reference 'T' can only appear in pack expansion or generic requirement}}
  fatalError()
}

func returnRepeatTuple<each T>(_ t: repeat each T) -> (repeat T) { // expected-error {{pack type 'T' must be referenced with 'each'}}
  fatalError()
}

func parameterAsPackTypeWithoutExpansion<each T>(_ t: T) -> repeat each T { // expected-error {{pack expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}
  fatalError()
}

func expansionOfNonPackType<T>(_ t: repeat each T) {}
// expected-error@-1 {{'each' cannot be applied to non-pack type 'T'}}{{29-29=each }}
// expected-error@-2 {{pack expansion 'T' must contain at least one pack reference}}

func tupleExpansion<each T, each U>(
  _ tuple1: (repeat each T),
  _ tuple2: (repeat each U)
) {
  _ = forward(repeat each tuple1.element)

  _ = zip(repeat each tuple1.element, with: repeat each tuple1.element)

  _ = zip(repeat each tuple1.element, with: repeat each tuple2.element)
  // expected-error@-1 {{global function 'zip(_:with:)' requires the type packs 'U' and 'T' have the same shape}}
}

protocol Generatable {
  static func generate() -> Self
}

func generateTuple<each T : Generatable>() -> (repeat each T) {
  (each T).generate()
  // expected-error@-1 {{pack reference 'T' can only appear in pack expansion or generic requirement}}

  return (repeat (each T).generate())
}

func packElementInvalidBinding<each T>(_ arg: repeat each T) {
  _ = (repeat print(each arg))

  let x = 1
  repeat print(each x)
  // expected-error@-1 {{'each' cannot be applied to non-pack type 'Int'}}
}

func copyIntoTuple<each T>(_ arg: repeat each T) -> (repeat each T) {
  return (repeat each arg)
}
func callCopyAndBind<T>(_ arg: repeat each T) {
  // expected-error@-1 {{'each' cannot be applied to non-pack type 'T'}}
  // expected-error@-2 {{pack expansion 'T' must contain at least one pack reference}}

  // Don't propagate errors for invalid declaration reference
  let result = copyIntoTuple(repeat each arg)
}

do {
  struct TestArgMatching {
    subscript<each T>(data arg: repeat each T) -> Int {
      get { 42 }
      set {}
    }
  }

  func test_that_variadic_generics_claim_unlabeled_arguments<each T>(_ args: repeat each T, test: inout TestArgMatching) {
    func testLabeled<each U>(data: repeat each U) {}
    func testUnlabeled<each U>(_: repeat each U) {}
    func testInBetween<each U>(_: repeat each U, other: String) {}

    testLabeled(data: repeat each args) // Ok
    testLabeled(data: repeat each args, 1) // Ok
    testLabeled(data: repeat each args, 1, 2, 3) // Ok

    testUnlabeled(repeat each args) // Ok
    testUnlabeled(repeat each args, 1) // Ok
    testUnlabeled(repeat each args, 1, 2, 3) // Ok

    testInBetween(repeat each args, 1, 2.0, other: "") // Ok

    _ = test[data: repeat each args]
    _ = test[data: repeat each args, 0, ""]

    test[data: repeat each args, "", 42] = 0
  }
}

func test_pack_expansion_materialization_from_lvalue_base() {
  struct Data<Value> {}

  struct Test<each T> {
    var data: (repeat Data<each T>)

    init() {
      self.data = (repeat Data<each T>())
      _ = (repeat each data.element) // Ok

      var tmp = (repeat Data<each T>()) // expected-warning {{never mutated}}
      _ = (repeat each tmp.element) // Ok

      // TODO: Add subscript test-case when syntax is supported.
    }
  }
}

func takesFunctionPack<each T, R>(functions: repeat ((each T) -> R)) {}

func forwardFunctionPack<each T>(functions: repeat (each T) -> Bool) {
  takesFunctionPack(functions: repeat each functions)
}
