// RUN: %target-typecheck-verify-swift

struct X { } // expected-note * {{did you mean 'X'?}}

// Simple examples
struct X1 {
  var stored : Int

  subscript (i : Int) -> Int {
    get {
      return stored
    }
    mutating
    set {
      stored = newValue
    }
  }
}

struct X2 {
  var stored : Int

  subscript (i : Int) -> Int {
    get {
      return stored + i
    }
    set(v) {
      stored = v - i
    }
  }
}

struct X3 {
  var stored : Int

  subscript (_ : Int) -> Int {
    get {
      return stored
    }
    set(v) {
      stored = v
    }
  }
}

struct X4 {
  var stored : Int

  subscript (i : Int, j : Int) -> Int {
    get {
      return stored + i + j
    }
    set(v) {
      stored = v + i - j
    }
  }
}

struct X5 {
  static var stored : Int = 1
  
  static subscript (i : Int) -> Int {
    get {
      return stored + i
    }
    set {
      stored = newValue - i
    }
  }
}

class X6 {
  static var stored : Int = 1
  
  class subscript (i : Int) -> Int {
    get {
      return stored + i
    }
    set {
      stored = newValue - i
    }
  }
}

protocol XP1 {
  subscript (i : Int) -> Int { get set }
  static subscript (i : Int) -> Int { get set }
}


// Semantic errors
struct Y1 {
  var x : X

  subscript(i: Int) -> Int {
    get {
      return x // expected-error{{cannot convert return expression of type 'X' to return type 'Int'}}
    }
    set {
      x = newValue // expected-error{{cannot assign value of type 'Int' to type 'X'}}
    }
  }
}

struct Y2 {
  subscript(idx: Int) -> TypoType { // expected-error {{use of undeclared type 'TypoType'}}
    get { repeat {} while true }
    set {}
  }
}

class Y3 {
  subscript(idx: Int) -> TypoType { // expected-error {{use of undeclared type 'TypoType'}}
    get { repeat {} while true }
    set {}
  }
}

class Y4 {
  var x = X()
  
  static subscript(idx: Int) -> X {
    get { return x } // expected-error {{instance member 'x' cannot be used on type 'Y4'}}
    set {}
  }
}

class Y5 {
  static var x = X()
  
  subscript(idx: Int) -> X {
    get { return x } // expected-error {{static member 'x' cannot be used on instance of type 'Y5'}}
    set {}
  }
}


protocol ProtocolGetSet0 {
  subscript(i: Int) -> Int {} // expected-error {{subscript declarations must have a getter}}
}
protocol ProtocolGetSet1 {
  subscript(i: Int) -> Int { get }
}
protocol ProtocolGetSet2 {
  subscript(i: Int) -> Int { set } // expected-error {{subscript with a setter must also have a getter}}
}
protocol ProtocolGetSet3 {
  subscript(i: Int) -> Int { get set }
}
protocol ProtocolGetSet4 {
  subscript(i: Int) -> Int { set get }
}

protocol ProtocolWillSetDidSet1 {
  subscript(i: Int) -> Int { willSet } // expected-error {{expected get or set in a protocol property}} expected-error {{subscript declarations must have a getter}}
}
protocol ProtocolWillSetDidSet2 {
  subscript(i: Int) -> Int { didSet } // expected-error {{expected get or set in a protocol property}} expected-error {{subscript declarations must have a getter}}
}
protocol ProtocolWillSetDidSet3 {
  subscript(i: Int) -> Int { willSet didSet } // expected-error 2 {{expected get or set in a protocol property}} expected-error {{subscript declarations must have a getter}}
}
protocol ProtocolWillSetDidSet4 {
  subscript(i: Int) -> Int { didSet willSet } // expected-error 2 {{expected get or set in a protocol property}} expected-error {{subscript declarations must have a getter}}
}

class DidSetInSubscript {
  subscript(_: Int) -> Int {
    didSet { // expected-error {{'didSet' is not allowed in subscripts}}
      print("eek")
    }
    get {}
  }
}

class WillSetInSubscript {
  subscript(_: Int) -> Int {
    willSet { // expected-error {{'willSet' is not allowed in subscripts}}
      print("eek")
    }
    get {}
  }
}

subscript(i: Int) -> Int { // expected-error{{'subscript' functions may only be declared within a type}}
  get {}
}

func f() {  // expected-note * {{did you mean 'f'?}}
  subscript (i: Int) -> Int { // expected-error{{'subscript' functions may only be declared within a type}}
    get {}
  }
}

struct NoSubscript { }

struct OverloadedSubscript {
  subscript(i: Int) -> Int {
    get {
      return i
    }
    set {}
  }

  subscript(i: Int, j: Int) -> Int {
    get { return i }
    set {}
  }
}

struct RetOverloadedSubscript {
  subscript(i: Int) -> Int {  // expected-note {{found this candidate}}
    get { return i }
    set {}
  }

  subscript(i: Int) -> Float {  // expected-note {{found this candidate}}
    get { return Float(i) }
    set {}
  }
}

struct MissingGetterSubscript1 {
  subscript (i : Int) -> Int {
  } // expected-error {{subscript must have accessors specified}}
}
struct MissingGetterSubscript2 {
  subscript (i : Int, j : Int) -> Int {
    set {} // expected-error{{subscript with a setter must also have a getter}}
  }
}

func test_subscript(_ x2: inout X2, i: Int, j: Int, value: inout Int, no: NoSubscript,
                    ovl: inout OverloadedSubscript, ret: inout RetOverloadedSubscript) {
  no[i] = value // expected-error{{value of type 'NoSubscript' has no subscripts}}

  value = x2[i]
  x2[i] = value

  value = ovl[i]
  ovl[i] = value

  value = ovl[i, j]
  ovl[i, j] = value

  value = ovl[(i, j, i)] // expected-error{{cannot convert value of type '(Int, Int, Int)' to expected argument type 'Int'}}

  ret[i] // expected-error{{ambiguous use of 'subscript(_:)'}}

  value = ret[i]
  ret[i] = value
  
  X5[i] = value
  value = X5[i]
}

func test_proto_static<XP1Type: XP1>(
                                     i: Int, value: inout Int,
                                     existential: inout XP1,
                                     generic: inout XP1Type
                                     ) {
  existential[i] = value
  value = existential[i]
  
  type(of: existential)[i] = value
  value = type(of: existential)[i]

  generic[i] = value
  value = generic[i]
  
  XP1Type[i] = value
  value = XP1Type[i]
}

func subscript_rvalue_materialize(_ i: inout Int) {
  i = X1(stored: 0)[i]
}

func subscript_coerce(_ fn: ([UnicodeScalar], [UnicodeScalar]) -> Bool) {}
func test_subscript_coerce() {
  subscript_coerce({ $0[$0.count-1] < $1[$1.count-1] })
}

struct no_index {
  subscript () -> Int { return 42 }
  func test() -> Int {
    return self[]
  }
}

struct tuple_index {
  subscript (x : Int, y : Int) -> (Int, Int) { return (x, y) }
  func test() -> (Int, Int) {
    return self[123, 456]
  }
}

struct MutableComputedGetter {
  var value: Int
  subscript(index: Int) -> Int {
    value = 5 // expected-error{{cannot assign to property: 'self' is immutable}}
    return 5
  }
  var getValue : Int {
    value = 5 // expected-error {{cannot assign to property: 'self' is immutable}}
    return 5
  }
}

struct MutableSubscriptInGetter {
  var value: Int
  subscript(index: Int) -> Int {
    get { // expected-note {{mark accessor 'mutating' to make 'self' mutable}}
      value = 5 // expected-error{{cannot assign to property: 'self' is immutable}}
      return 5
    }
  }
}

protocol Protocol {}
protocol RefinedProtocol: Protocol {}
class SuperClass {}
class SubClass: SuperClass {}
class SubSubClass: SubClass {}
class ClassConformingToProtocol: Protocol {}
class ClassConformingToRefinedProtocol: RefinedProtocol {}

struct GenSubscriptFixitTest {
  subscript<T>(_ arg: T) -> Bool { return true } // expected-note 3 {{declared here}}
}

func testGenSubscriptFixit(_ s0: GenSubscriptFixitTest) {

  _ = s0.subscript("hello")
  // expected-error@-1 {{value of type 'GenSubscriptFixitTest' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{27-28=]}}
}

func testUnresolvedMemberSubscriptFixit(_ s0: GenSubscriptFixitTest) {

  _ = s0.subscript
  // expected-error@-1 {{value of type 'GenSubscriptFixitTest' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-19=[<#index#>]}}

  s0.subscript = true
  // expected-error@-1 {{value of type 'GenSubscriptFixitTest' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{5-15=[<#index#>]}}
}

struct SubscriptTest1 {
  subscript(keyword:String) -> Bool { return true }
  // expected-note@-1 4 {{found this candidate}}
  subscript(keyword:String) -> String? {return nil }
  // expected-note@-1 4 {{found this candidate}}

  subscript(arg: SubClass) -> Bool { return true } // expected-note {{declared here}}
  subscript(arg: Protocol) -> Bool { return true } // expected-note 2 {{declared here}}

  subscript(arg: (foo: Bool, bar: (Int, baz: SubClass)), arg2: String) -> Bool { return true }
  // expected-note@-1 3 {{declared here}}
}

func testSubscript1(_ s1 : SubscriptTest1) {
  let _ : Int = s1["hello"]  // expected-error {{ambiguous subscript with base type 'SubscriptTest1' and index type 'String'}}

  if s1["hello"] {}

  _ = s1.subscript((true, (5, SubClass())), "hello")
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{52-53=]}}
  _ = s1.subscript((true, (5, baz: SubSubClass())), "hello")
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{60-61=]}}
  _ = s1.subscript((fo: true, (5, baz: SubClass())), "hello")
  // expected-error@-1 {{cannot convert value of type '(fo: Bool, (Int, baz: SubClass))' to expected argument type '(foo: Bool, bar: (Int, baz: SubClass))'}}
  // expected-error@-2 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}}
  _ = s1.subscript(SubSubClass())
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{33-34=]}}
  _ = s1.subscript(ClassConformingToProtocol())
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{47-48=]}}
  _ = s1.subscript(ClassConformingToRefinedProtocol())
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{54-55=]}}
  _ = s1.subscript(true)
  // expected-error@-1 {{cannot invoke 'subscript' with an argument list of type '(Bool)'}}
  // expected-note@-2 {{overloads for 'subscript' exist with these partially matching parameter lists: (Protocol), (String), (SubClass)}}
  _ = s1.subscript(SuperClass())
  // expected-error@-1 {{cannot invoke 'subscript' with an argument list of type '(SuperClass)'}}
  // expected-note@-2 {{overloads for 'subscript' exist with these partially matching parameter lists: (Protocol), (String), (SubClass)}}
  _ = s1.subscript("hello")
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}}
  _ = s1.subscript("hello"
  // expected-error@-1 {{value of type 'SubscriptTest1' has no property or method named 'subscript'; did you mean to use the subscript operator?}}
  // expected-note@-2 {{to match this opening '('}}

  let _ = s1["hello"]
  // expected-error@-1 {{ambiguous use of 'subscript(_:)'}}
  // expected-error@-2 {{expected ')' in expression list}}
}

struct SubscriptTest2 {
  subscript(a : String, b : Int) -> Int { return 0 } // expected-note {{candidate expects value of type 'Int' at position #1}}
  // expected-note@-1 {{declared here}}
    subscript(a : String, b : String) -> Int { return 0 } // expected-note {{candidate expects value of type 'String' at position #1}}
}

func testSubscript1(_ s2 : SubscriptTest2) {
  _ = s2["foo"] // expected-error {{cannot subscript a value of type 'SubscriptTest2' with an argument of type 'String'}}
  // expected-note @-1 {{overloads for 'subscript' exist with these partially matching parameter lists: (String, Int), (String, String)}}

  let a = s2["foo", 1.0] // expected-error {{no exact matches in call to subscript}}

  _ = s2.subscript("hello", 6)
  // expected-error@-1 {{value of type 'SubscriptTest2' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{30-31=]}}
  let b = s2[1, "foo"] // expected-error {{cannot convert value of type 'Int' to expected argument type 'String'}}

  // rdar://problem/27449208
  let v: (Int?, [Int]?) = (nil [17]) // expected-error {{cannot subscript a nil literal value}}
}

// sr-114 & rdar://22007370

class Foo {
    subscript(key: String) -> String { // expected-note {{'subscript(_:)' previously declared here}}
        get { a } // expected-error {{use of unresolved identifier 'a'}}
        set { b } // expected-error {{use of unresolved identifier 'b'}}
    }
    
    subscript(key: String) -> String { // expected-error {{invalid redeclaration of 'subscript(_:)'}}
        get { _ = 0; a } // expected-error {{use of unresolved identifier 'a'}}
        set { b } // expected-error {{use of unresolved identifier 'b'}}
    }
}

// <rdar://problem/23952125> QoI: Subscript in protocol with missing {}, better diagnostic please
protocol r23952125 {
  associatedtype ItemType
  var count: Int { get }
  subscript(index: Int) -> ItemType  // expected-error {{subscript in protocol must have explicit { get } or { get set } specifier}} {{36-36= { get <#set#> \}}}

  var c : Int // expected-error {{property in protocol must have explicit { get } or { get set } specifier}} {{14-14= { get <#set#> \}}}
}

// SR-2575
struct SR2575 {
  subscript() -> Int { // expected-note {{declared here}}
    return 1
  }
}

SR2575().subscript()
// expected-error@-1 {{value of type 'SR2575' has no property or method named 'subscript'; did you mean to use the subscript operator?}} {{9-10=}} {{10-19=}} {{19-20=[}} {{20-21=]}}

// SR-7890

struct InOutSubscripts {
  subscript(x1: inout Int) -> Int { return 0 }
  // expected-error@-1 {{'inout' must not be used on subscript parameters}}

  subscript(x2: inout Int, y2: inout Int) -> Int { return 0 }
  // expected-error@-1 2{{'inout' must not be used on subscript parameters}}

  subscript(x3: (inout Int) -> ()) -> Int { return 0 } // ok
  subscript(x4: (inout Int, inout Int) -> ()) -> Int { return 0 } // ok

  subscript(inout x5: Int) -> Int { return 0 }
  // expected-error@-1 {{'inout' before a parameter name is not allowed, place it before the parameter type instead}}
  // expected-error@-2 {{'inout' must not be used on subscript parameters}}
}
