// RUN: %target-swift-emit-silgen %s | %FileCheck %s
// RUN: %target-swift-emit-ir %s

func foo() -> Int {
  if .random() { 1 } else { 2 }
}

// CHECK-LABEL: sil hidden [ossa] @$s7if_expr3fooSiyF : $@convention(thin) () -> Int
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       cond_br {{%[0-9]+}}, [[TRUEBB:bb[0-9]+]], [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[TRUEBB]]:
// CHECK:       [[ONE_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 1
// CHECK:       [[ONE:%[0-9]+]] = apply {{%[0-9]+}}([[ONE_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[ONE]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       [[TWO_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 2
// CHECK:       [[TWO:%[0-9]+]] = apply {{%[0-9]+}}([[TWO_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[TWO]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int

class C {}

func bar(_ x: C) -> C {
  if .random() { x } else { C() }
}

// CHECK-LABEL: sil hidden [ossa] @$s7if_expr3baryAA1CCADF : $@convention(thin) (@guaranteed C) -> @owned C
// CHECK:       bb0([[CPARAM:%[0-9]+]] : @guaranteed $C):
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $C
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*C
// CHECK:       cond_br {{%[0-9]+}}, [[TRUEBB:bb[0-9]+]], [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[TRUEBB]]:
// CHECK:       [[C:%[0-9]+]] = copy_value [[CPARAM]] : $C
// CHECK:       store [[C]] to [init] [[RESULT]] : $*C
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       [[CTOR:%[0-9]+]] = function_ref @$s7if_expr1CCACycfC : $@convention(method) (@thick C.Type) -> @owned C
// CHECK:       [[C:%[0-9]+]] = apply [[CTOR]]({{%[0-9]+}}) : $@convention(method) (@thick C.Type) -> @owned C
// CHECK:       store [[C]] to [init] [[RESULT]] : $*C
// CHECK:       br [[EXITBB]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [take] [[RESULT]] : $*C
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*C
// CHECK:       return [[VAL]] : $C

struct Err: Error {}

func baz() throws -> Int {
  if .random() {
    0
  } else if .random() {
    throw Err()
  } else {
    2
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s7if_expr3bazSiyKF : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       cond_br {{%[0-9]+}}, [[TRUEBB:bb[0-9]+]], [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       cond_br {{%[0-9]+}}, [[FALSETRUEBB:bb[0-9]+]], [[FALSEFALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSETRUEBB]]:
// CHECK:       throw {{%[0-9]+}} : $any Error
//
// CHECK:       [[FALSEFALSEBB]]:
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int

func qux() throws -> Int {
  if .random() { 0 } else { try baz() }
}

// CHECK-LABEL: sil hidden [ossa] @$s7if_expr3quxSiyKF : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       cond_br {{%[0-9]+}}, [[TRUEBB:bb[0-9]+]], [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       try_apply {{%[0-9]+}}() : $@convention(thin) () -> (Int, @error any Error), normal [[NORMALBB:bb[0-9]+]], error [[ERRORBB:bb[0-9]+]]
//
// CHECK:       [[NORMALBB]]([[BAZVAL:%[0-9]+]] : $Int):
// CHECK:       store [[BAZVAL]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int
//
// CHECK:       [[ERRORBB]]([[ERR:%[0-9]+]] : @owned $any Error):
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       throw [[ERR]] : $any Error

func optionalVoidCrash() {
  func takesClosure<T>(_ x: () -> T) {}

  struct S {
    func bar() {}
  }

  var s: S?
  takesClosure {
    if true {
      s?.bar()
    } else {
      ()
    }
  }
}

func testClosure() throws -> Int {
  let fn = {
    if .random() {
      0
    } else {
      try baz()
    }
  }
  return try fn()
}

// CHECK-LABEL: sil private [ossa] @$s7if_expr11testClosureSiyKFSiyKcfU_ : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       cond_br {{%[0-9]+}}, [[TRUEBB:bb[0-9]+]], [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       try_apply {{%[0-9]+}}() : $@convention(thin) () -> (Int, @error any Error), normal [[NORMALBB:bb[0-9]+]], error [[ERRORBB:bb[0-9]+]]
//
// CHECK:       [[NORMALBB]]([[BAZVAL:%[0-9]+]] : $Int):
// CHECK:       store [[BAZVAL]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int
//
// CHECK:       [[ERRORBB]]([[ERR:%[0-9]+]] : @owned $any Error):
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       throw [[ERR]] : $any Error

func testNested() throws -> Int {
  if .random() {
    0
  } else {
    if .random() {
      throw Err()
    } else {
      2
    }
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s7if_expr10testNestedSiyKF : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       cond_br {{%[0-9]+}}, [[TRUEBB:bb[0-9]+]], [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       cond_br {{%[0-9]+}}, [[FALSETRUEBB:bb[0-9]+]], [[FALSEFALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSETRUEBB]]:
// CHECK:       throw {{%[0-9]+}} : $any Error
//
// CHECK:       [[FALSEFALSEBB]]:
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int

func testVar() -> Int {
  let x = if .random() { 1 } else { 2 }
  return x
}

func testCatch() -> Int {
  do {
    let x = if .random() {
      0
    } else {
      throw Err()
    }
    return x
  } catch {
    return 0
  }
}

struct TestPropertyInit {
  var x = if .random() { 1 } else { 0 }
  lazy var y = if .random() { 1 } else { 0 }
}

func testAssignment() {
  var x = 0
  x = if .random() { 0 } else { 1 }
  let fn = {
    x = if .random() { 0 } else { 1 }
  }
}

func nestedType() throws -> Int {
  if .random() {
    struct S: Error {}
    throw S()
  } else {
    0
  }
}
