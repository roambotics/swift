// RUN: %target-swift-frontend -typecheck -verify -enable-opaque-result-types %s

protocol P {
  func paul()
  mutating func priscilla()
}
protocol Q { func quinn() }
extension Int: P, Q { func paul() {}; mutating func priscilla() {}; func quinn() {} }
extension String: P, Q { func paul() {}; mutating func priscilla() {}; func quinn() {} }
extension Array: P, Q { func paul() {}; mutating func priscilla() {}; func quinn() {} }

class C {}
class D: C, P, Q { func paul() {}; func priscilla() {}; func quinn() {} }

// TODO: Should be valid

let property: some P = 1 // TODO expected-error{{cannot convert}}
let deflessProperty: some P // TODO e/xpected-error{{butz}}

struct GenericProperty<T: P> {
  var x: T
  var property: some P {
    return x
  }
}

let (bim, bam): some P = (1, 2) // expected-error{{'some' type can only be declared on a single property declaration}}
var computedProperty: some P {
  get { return 1 }
  set { _ = newValue + 1 } // TODO expected-error{{}} expected-note{{}}
}
struct SubscriptTest {
  subscript(_ x: Int) -> some P {
    return x
  }
}

func bar() -> some P {
  return 1
}
func bas() -> some P & Q {
  return 1
}
func zim() -> some C {
  return D()
}
func zang() -> some C & P & Q {
  return D()
}
func zung() -> some AnyObject {
  return D()
}
func zoop() -> some Any {
  return D()
}
func zup() -> some Any & P {
  return D()
}
func zip() -> some AnyObject & P {
  return D()
}
func zorp() -> some Any & C & P {
  return D()
}
func zlop() -> some C & AnyObject & P {
  return D()
}

// Don't allow opaque types to propagate by inference into other global decls'
// types
struct Test {
  let inferredOpaque = bar() // expected-error{{inferred type}}
  let inferredOpaqueStructural = Optional(bar()) // expected-error{{inferred type}}
  let inferredOpaqueStructural2 = (bar(), bas()) // expected-error{{inferred type}}
}

//let zingle = {() -> some P in 1 } // FIXME ex/pected-error{{'some' types are only implemented}}

// Invalid positions

typealias Foo = some P // expected-error{{'some' types are only implemented}}

func blibble(blobble: some P) {} // expected-error{{'some' types are only implemented}}

let blubble: () -> some P = { 1 } // expected-error{{'some' types are only implemented}}

func blib() -> P & some Q { return 1 } // expected-error{{'some' should appear at the beginning}}
func blab() -> (P, some Q) { return (1, 2) } // expected-error{{'some' types are only implemented}}
func blob() -> (some P) -> P { return { $0 } } // expected-error{{'some' types are only implemented}}
func blorb<T: some P>(_: T) { } // expected-error{{'some' types are only implemented}}
func blub<T>() -> T where T == some P { return 1 } // expected-error{{'some' types are only implemented}} expected-error{{cannot convert}}

protocol OP: some P {} // expected-error{{'some' types are only implemented}}

func foo() -> some P {
  let x = (some P).self // expected-error*{{}}
  return 1
}

// Invalid constraints

let zug: some Int = 1 // FIXME expected-error{{must specify only}}
let zwang: some () = () // FIXME expected-error{{must specify only}}
let zwoggle: some (() -> ()) = {} // FIXME expected-error{{must specify only}}

// Type-checking of expressions of opaque type

func alice() -> some P { return 1 }
func bob() -> some P { return 1 }

func grace<T: P>(_ x: T) -> some P { return x }

func typeIdentity() {
  do {
    var a = alice()
    a = alice()
    a = bob() // expected-error{{}}
    a = grace(1) // expected-error{{}}
    a = grace("two") // expected-error{{}}
  }

  do {
    var af = alice
    af = alice
    af = bob // expected-error{{}}
    af = grace // expected-error{{}}
  }

  do {
    var b = bob()
    b = alice() // expected-error{{}}
    b = bob()
    b = grace(1) // expected-error{{}}
    b = grace("two") // expected-error{{}}
  }

  do {
    var gi = grace(1)
    gi = alice() // expected-error{{}}
    gi = bob() // expected-error{{}}
    gi = grace(2)
    gi = grace("three") // expected-error{{}}
  }

  do {
    var gs = grace("one")
    gs = alice() // expected-error{{}}
    gs = bob() // expected-error{{}}
    gs = grace(2) // expected-error{{}}
    gs = grace("three")
  }

  // The opaque type should conform to its constraining protocols
  do {
    let gs = grace("one")
    var ggs = grace(gs)
    ggs = grace(gs)
  }

  // The opaque type should expose the members implied by its protocol
  // constraints
  // TODO: associated types
  do {
    var a = alice()
    a.paul()
    a.priscilla()
  }
}

func recursion(x: Int) -> some P {
  if x == 0 {
    return 0
  }
  return recursion(x: x - 1)
}

func noReturnStmts() -> some P { fatalError() } // expected-error{{no return statements}}

func mismatchedReturnTypes(_ x: Bool, _ y: Int, _ z: String) -> some P { // expected-error{{do not have matching underlying types}}
  if x {
    return y // expected-note{{underlying type 'Int'}}
  } else {
    return z // expected-note{{underlying type 'String'}}
  }
}

var mismatchedReturnTypesProperty: some P { // expected-error{{do not have matching underlying types}}
  if true {
    return 0 // expected-note{{underlying type 'Int'}}
  } else {
    return "" // expected-note{{underlying type 'String'}}
  }
}

struct MismatchedReturnTypesSubscript {
  subscript(x: Bool, y: Int, z: String) -> some P { // expected-error{{do not have matching underlying types}}
    if x {
      return y // expected-note{{underlying type 'Int'}}
    } else {
      return z // expected-note{{underlying type 'String'}}
    }
  }
}

func jan() -> some P {
  return [marcia(), marcia(), marcia()]
}
func marcia() -> some P {
  return [marcia(), marcia(), marcia()] // expected-error{{defines the opaque type in terms of itself}}
}

protocol R {
  associatedtype S: P, Q // expected-note*{{}}

  func r_out() -> S
  func r_in(_: S)
}

extension Int: R {
  func r_out() -> String {
    return ""
  }
  func r_in(_: String) {}
}

func candace() -> some R {
  return 0
}
func doug() -> some R {
  return 0
}

func gary<T: R>(_ x: T) -> some R {
  return x
}

func sameType<T>(_: T, _: T) {}

func associatedTypeIdentity() {
  let c = candace()
  let d = doug()

  var cr = c.r_out()
  cr = candace().r_out()
  cr = doug().r_out() // expected-error{{}}

  var dr = d.r_out()
  dr = candace().r_out() // expected-error{{}}
  dr = doug().r_out()

  c.r_in(cr)
  c.r_in(c.r_out())
  c.r_in(dr) // expected-error{{}}
  c.r_in(d.r_out()) // expected-error{{}}

  d.r_in(cr) // expected-error{{}}
  d.r_in(c.r_out()) // expected-error{{}}
  d.r_in(dr)
  d.r_in(d.r_out())

  cr.paul()
  cr.priscilla()
  cr.quinn()
  dr.paul()
  dr.priscilla()
  dr.quinn()

  sameType(cr, c.r_out())
  sameType(dr, d.r_out())
  sameType(cr, dr) // expected-error{{}}
  sameType(gary(candace()).r_out(), gary(candace()).r_out())
  sameType(gary(doug()).r_out(), gary(doug()).r_out())
  sameType(gary(doug()).r_out(), gary(candace()).r_out()) // expected-error{{}}
}

/* TODO: diagnostics
struct DoesNotConform {}

func doesNotConform() -> some P {
  return DoesNotConform()
}

var doesNotConformProp: some P = DoesNotConform()

var DoesNotConformComputedProp: some P {
  return DoesNotConform()
}
*/


