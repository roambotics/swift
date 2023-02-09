// RUN: %target-typecheck-verify-swift -enable-experimental-move-only

// a concrete move-only type
@_moveOnly struct MO {
  var x: Int?
}

@_moveOnly struct Container {
  var mo: MO = MO()
}

// utilities

struct LocalArray<Element> {}

protocol P {}

protocol Box<T> {
  associatedtype T
  func get() -> T
}

class RefBox<T>: Box {
  var val: T
  init(_ t: T) { val = t }
  func get() -> T { return val }
}

struct ValBox<T>: Box {
  var val: T
  init(_ t: T) { val = t }
  func get() -> T { return val }
}

class NotStoredGenerically<T> {
  func take(_ t: T) {}
  func give() -> T { fatalError("todo") }
}

enum Maybe<T> {
  case none
  case just(T)
}

func takeConcrete(_ m: MO) {}
func takeGeneric<T>(_ t: T) {}
func takeGenericSendable<T>(_ t: T) where T: Sendable {}
func takeMaybe<T>(_ m: Maybe<T>) {}
func takeAnyBoxErased(_ b: any Box) {}
func takeAnyBox<T>(_ b: any Box<T>) {}
func takeAny(_ a: Any) {}
func takeAnyObject(_ a: AnyObject) {}
func genericVarArg<T>(_ t: T...) {}

var globalMO: MO = MO()


// ----------------------
// --- now some tests ---
// ----------------------

// some top-level tests
let _: MO = globalMO
takeGeneric(globalMO) // expected-error {{move-only type 'MO' cannot be used with generics yet}}




func testAny() {
  let _: Any = MO() // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  takeAny(MO()) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
}

func testBasic(_ mo: MO) {
  takeConcrete(globalMO)
  takeConcrete(MO())

  takeGeneric(globalMO) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  takeGeneric(MO()) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  takeGeneric(mo) // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  takeAny(mo) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  print(mo) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  _ = "\(mo)" // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let _: String = String(describing: mo) // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  takeGeneric { () -> Int? in mo.x }
  genericVarArg(5)
  genericVarArg(mo) // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  takeGeneric( (mo, 5) ) // expected-error {{global function 'takeGeneric' requires that 'MO' conform to '_Copyable'}}
  takeGenericSendable((mo, mo)) // expected-error 2{{global function 'takeGenericSendable' requires that 'MO' conform to '_Copyable'}}

  let singleton : (MO) = (mo)
  takeGeneric(singleton) // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  takeAny((mo)) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  takeAny((mo, mo)) // expected-error {{move-only type '(MO, MO)' cannot be used with generics yet}}
}

func checkBasicBoxes() {
  let mo = MO()

  let vb = ValBox(_move mo) // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}
  _ = vb.get()
  _ = vb.val

  let rb = RefBox(MO())  // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}
  _ = rb.get()
  _ = rb.val

  let vb2: ValBox<MO> = .init(MO())  // expected-error {{move-only type 'MO' cannot be used with generics yet}}
}

func checkExistential() {
  takeAnyBox( // expected-error {{move-only type 'MO' cannot be used with generics yet}}
      RefBox(MO())) // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}

  takeAnyBox( // expected-error {{move-only type 'MO' cannot be used with generics yet}}
      ValBox(globalMO)) // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}

  takeAnyBoxErased(
      RefBox(MO())) // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}

  takeAnyBoxErased(
      ValBox(globalMO)) // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}
}

func checkMethodCalls() {
  let tg: NotStoredGenerically<MO> = NotStoredGenerically() // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  tg.take(MO())
  tg.give()

  let _: Maybe<MO> = .none // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let _ = Maybe<MO>.just(MO()) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let _: Maybe<MO> = .just(MO()) // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  takeMaybe(.just(MO())) // expected-error 2{{move-only type 'MO' cannot be used with generics yet}}

  takeMaybe(true ? .none : .just(MO())) // expected-error 3{{move-only type 'MO' cannot be used with generics yet}}
}

func checkCasting(_ b: any Box, _ mo: MO, _ a: Any) {
  // casting dynamically is allowed, but should always fail since you can't
  // construct such a type.
  let box = b as! ValBox<MO> // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let dup = box

  let _: MO = dup.get()
  let _: MO = dup.val

  let _: Sendable = (MO(), MO()) // expected-error {{move-only type '(MO, MO)' cannot be used with generics yet}}
  let _: Sendable = MO() // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let _: _Copyable = mo // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let _: AnyObject = MO() // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  let _: Any = mo // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  _ = MO() as P // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  _ = MO() as any P // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  _ = MO() as Any // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  _ = MO() as MO
  _ = MO() as AnyObject // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  _ = 5 as MO // expected-error {{cannot convert value of type 'Int' to type 'MO' in coercion}}
  _ = a as MO // expected-error {{cannot convert value of type 'Any' to type 'MO' in coercion}}
  _ = b as MO // expected-error {{cannot convert value of type 'any Box' to type 'MO' in coercion}}

  // FIXME(kavon): make sure at runtime these casts actually fail, or just make them errors? (rdar://104900293)

  _ = MO() is AnyHashable // expected-warning {{cast from 'MO' to unrelated type 'AnyHashable' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() is AnyObject // expected-warning {{cast from 'MO' to unrelated type 'AnyObject' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() is Any // expected-warning {{cast from 'MO' to unrelated type 'Any' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() is P // expected-warning {{cast from 'MO' to unrelated type 'any P' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() is MO // expected-warning {{'is' test is always true}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}

  _ = 5 is MO // expected-warning {{cast from 'Int' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = a is MO // expected-warning {{cast from 'Any' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = b is MO // expected-warning {{cast from 'any Box' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}

  _ = MO() as! AnyHashable // expected-warning {{cast from 'MO' to unrelated type 'AnyHashable' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as! AnyObject // expected-warning {{cast from 'MO' to unrelated type 'AnyObject' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as! Any // expected-warning {{cast from 'MO' to unrelated type 'Any' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as! P // expected-warning {{cast from 'MO' to unrelated type 'any P' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as! MO // expected-warning {{forced cast of 'MO' to same type has no effect}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}

  _ = 5 as! MO // expected-warning {{cast from 'Int' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = a as! MO // expected-warning {{cast from 'Any' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = b as! MO // expected-warning {{cast from 'any Box' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}

  _ = MO() as? AnyHashable // expected-warning {{cast from 'MO' to unrelated type 'AnyHashable' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as? AnyObject // expected-warning {{cast from 'MO' to unrelated type 'AnyObject' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as? Any // expected-warning {{cast from 'MO' to unrelated type 'Any' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as? P // expected-warning {{cast from 'MO' to unrelated type 'any P' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = MO() as? MO // expected-warning {{conditional cast from 'MO' to 'MO' always succeeds}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}

  _ = 5 as? MO // expected-warning {{cast from 'Int' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = a as? MO // expected-warning {{cast from 'Any' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}
  _ = b as? MO // expected-warning {{cast from 'any Box' to unrelated type 'MO' always fails}}
  // expected-error@-1 {{move-only types cannot be conditionally cast}}

}

func checkStdlibTypes(_ mo: MO) {
  let _: [MO] = // expected-error {{move-only type 'MO' cannot be used with generics yet}}
      [MO(), MO()]
  let _: [MO] = // expected-error {{move-only type 'MO' cannot be used with generics yet}}
      []
  let _: [String: MO] = // expected-error {{move-only type 'MO' cannot be used with generics yet}}
      ["hello" : MO()]

  // i think this one's only caught b/c of the 'Any' change
  _ = [MO()] // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  let _: Array<MO> = .init() // expected-error {{move-only type 'MO' cannot be used with generics yet}}
  _ = [MO]() // expected-error {{move-only type 'MO' cannot be used with generics yet}}

  let s: String = "hello \(mo)" // expected-error {{move-only type 'MO' cannot be used with generics yet}}
}

func copyableExistentials(_ a: Any, _ e1: Error, _ e2: any Error, _ ah: AnyHashable) {
  takeGeneric(a)
  takeGeneric(e1)
  takeGeneric(e2)
  takeGeneric(ah)
}

// ensure that associated types can't be witnessed by move-only types

protocol HasType<Ty> {
  associatedtype Ty // expected-note 3{{protocol requires nested type 'Ty'; do you want to add it?}}
}

class SomeGuy: HasType { // expected-error {{type 'SomeGuy' does not conform to protocol 'HasType'}}
  typealias Ty = MO // expected-note {{possibly intended match 'SomeGuy.Ty' (aka 'MO') does not conform to '_Copyable'}}
}

struct AnotherGuy: HasType { // expected-error {{type 'AnotherGuy' does not conform to protocol 'HasType'}}
  @_moveOnly struct Ty {} // expected-note {{possibly intended match 'AnotherGuy.Ty' does not conform to '_Copyable'}}
}

protocol Gives: HasType {
  func give() -> Ty
}

struct GenerousGuy: Gives { // expected-error {{type 'GenerousGuy' does not conform to protocol 'HasType'}}
  typealias Ty = MO // expected-note {{possibly intended match 'GenerousGuy.Ty' (aka 'MO') does not conform to '_Copyable'}}
  func give() -> Ty {}
}
