// RUN: %target-typecheck-verify-swift -enable-experimental-variadic-generics

func f1<T...>() -> T... {}
// expected-error@-1 {{variadic expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}

func f2<T...>() -> (T...) {}
// okay

struct G<T...> {}

func f3<T...>() -> G<T... > {}

protocol P<T> {
  associatedtype T
}

func f4<T...>() -> any P<T... > {}

typealias T1<T...> = T...
// expected-error@-1 {{variadic expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}

typealias T2<T...> = (T...)

func f4<T...>() -> () -> T... {}
// expected-error@-1 {{variadic expansion '() -> T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}

func f5<T...>() -> () -> (T...) {}

func f6<T...>() -> (T...) -> () {}

enum E<T...> {
  case f1(_: T...)

  case f2(_: G<T... >)

  var x: T... { fatalError() }
  // expected-error@-1 {{variadic expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}

  var x: (T...) { fatalError() }

  subscript(_: T...) -> Int { fatalError() }

  subscript() -> T... { fatalError() }
  // expected-error@-1 {{variadic expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}

  subscript() -> (T...) { fatalError() }
}

func withWhereClause<T...>(_ x: T...) where T...: P {}
// expected-error@-1 {{variadic expansion 'T' cannot appear outside of a function parameter list, function result, tuple element or generic argument list}}
