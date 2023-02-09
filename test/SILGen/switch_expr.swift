// RUN: %target-swift-emit-silgen %s | %FileCheck %s
// RUN: %target-swift-emit-ir %s

func foo() -> Int {
  switch Bool.random() {
    case true:
      1
    case false:
      2
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s11switch_expr3fooSiyF : $@convention(thin) () -> Int
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       switch_value {{%[0-9]+}} : $Builtin.Int1, case {{%[0-9]+}}: [[TRUEBB:bb[0-9]+]], case {{%[0-9]+}}: [[FALSEBB:bb[0-9]+]]
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
  switch Bool.random() {
    case true:
      x
    case false:
      C()
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s11switch_expr3baryAA1CCADF : $@convention(thin) (@guaranteed C) -> @owned C
// CHECK:       bb0([[CPARAM:%[0-9]+]] : @guaranteed $C):
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $C
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*C
// CHECK:       switch_value {{%[0-9]+}} : $Builtin.Int1, case {{%[0-9]+}}: [[TRUEBB:bb[0-9]+]], case {{%[0-9]+}}: [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[TRUEBB]]:
// CHECK:       [[C:%[0-9]+]] = copy_value [[CPARAM]] : $C
// CHECK:       store [[C]] to [init] [[RESULT]] : $*C
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       [[CTOR:%[0-9]+]] = function_ref @$s11switch_expr1CCACycfC : $@convention(method) (@thick C.Type) -> @owned C
// CHECK:       [[C:%[0-9]+]] = apply [[CTOR]]({{%[0-9]+}}) : $@convention(method) (@thick C.Type) -> @owned C
// CHECK:       store [[C]] to [init] [[RESULT]] : $*C
// CHECK:       br [[EXITBB]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [take] [[RESULT]] : $*C
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*C
// CHECK:       return [[VAL]] : $C

struct Err: Error {}

enum E { case a, b, c }

func baz(_ e: E) throws -> Int {
  switch e {
  case .a:
    1
  case .b:
    throw Err()
  default:
    2
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s11switch_expr3bazySiAA1EOKF : $@convention(thin) (E) -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       switch_enum %0 : $E, case #E.a!enumelt: [[ABB:bb[0-9]+]], case #E.b!enumelt: [[BBB:bb[0-9]+]], default [[DEFBB:bb[0-9]+]]
//
// CHECK:       [[ABB]]:
// CHECK:       [[ONE_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 1
// CHECK:       [[ONE:%[0-9]+]] = apply {{%[0-9]+}}([[ONE_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[ONE]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[BBB]]:
// CHECK:       throw {{%[0-9]+}} : $any Error
//
// CHECK:       [[DEFBB]]:
// CHECK:       [[TWO_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 2
// CHECK:       [[TWO:%[0-9]+]] = apply {{%[0-9]+}}([[TWO_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[TWO]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int

func qux() throws -> Int {
  switch Bool.random() {
    case true:
      0
    case false:
      try baz(.a)
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s11switch_expr3quxSiyKF : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       switch_value {{%[0-9]+}} : $Builtin.Int1, case {{%[0-9]+}}: [[TRUEBB:bb[0-9]+]], case {{%[0-9]+}}: [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       try_apply {{%[0-9]+}}({{%[0-9]+}}) : $@convention(thin) (E) -> (Int, @error any Error), normal [[NORMALBB:bb[0-9]+]], error [[ERRORBB:bb[0-9]+]]
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

func testFallthrough() throws -> Int {
  switch Bool.random() {
  case true:
    if .random() { fallthrough }
    throw Err()
  case false:
    1
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s11switch_expr15testFallthroughSiyKF : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       switch_value {{%[0-9]+}} : $Builtin.Int1, case {{%[0-9]+}}: [[TRUEBB:bb[0-9]+]], case {{%[0-9]+}}: [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[TRUEBB]]:
// CHECK:       cond_br {{.*}}, [[IFTRUEBB:bb[0-9]+]], [[IFFALSEBB:bb[0-9]+]]
//
// CHECK:       [[IFTRUEBB]]:
// CHECK:       br [[ACTUALFALSEBB:bb[0-9]+]]
//
// CHECK:       [[IFFALSEBB]]:
// CHECK:       throw {{%[0-9]+}} : $any Error
//
// CHECK:       [[FALSEBB]]:
// CHECK:       br [[ACTUALFALSEBB]]
//
// CHECK:       [[ACTUALFALSEBB]]:
// CHECK:       [[ONE_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 1
// CHECK:       [[ONE:%[0-9]+]] = apply {{%[0-9]+}}([[ONE_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[ONE]] to [trivial] [[RESULT]] : $*Int
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int

func testClosure() throws -> Int {
  let fn = {
    switch Bool.random() {
    case true:
      0
    case false:
      try baz(.a)
    }
  }
  return try fn()
}

// CHECK-LABEL: sil private [ossa] @$s11switch_expr11testClosureSiyKFSiyKcfU_ : $@convention(thin) () -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       switch_value {{%[0-9]+}} : $Builtin.Int1, case {{%[0-9]+}}: [[TRUEBB:bb[0-9]+]], case {{%[0-9]+}}: [[FALSEBB:bb[0-9]+]]
//
// CHECK:       [[FALSEBB]]:
// CHECK:       try_apply {{%[0-9]+}}({{%[0-9]+}}) : $@convention(thin) (E) -> (Int, @error any Error), normal [[NORMALBB:bb[0-9]+]], error [[ERRORBB:bb[0-9]+]]
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

func testVar1() -> Int {
  let x = switch Bool.random() {
    case let b where b == true:
      1
    case false:
      0
    default:
      2
  }
  return x
}

func testVar2() -> Int {
  let x = switch Bool.random() {
    case let b where b == true:
      1
    case false:
      0
    default:
      2
  }
  return x
}

func testCatch() -> Int {
  do {
    let x = switch Bool.random() {
    case true:
      0
    case false:
      throw Err()
    }
    return x
  } catch {
    return 0
  }
}

struct TestPropertyInit {
  var x = switch Bool.random() {
    case let b where b == true:
      1
    case false:
      0
    default:
      2
  }
  lazy var y = switch Bool.random() {
    case let b where b == true:
      1
    case false:
      0
    default:
      2
  }
}

func testNested(_ e: E) throws -> Int {
  switch e {
  case .a:
    1
  default:
    switch e {
    case .b:
      throw Err()
    default:
      2
    }
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s11switch_expr10testNestedySiAA1EOKF : $@convention(thin) (E) -> (Int, @error any Error)
// CHECK:       [[RESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[RESULT:%[0-9]+]] = mark_uninitialized [var] [[RESULT_STORAGE]] : $*Int
// CHECK:       switch_enum %0 : $E, case #E.a!enumelt: [[ABB:bb[0-9]+]], default [[DEFBB:bb[0-9]+]]
//
// CHECK:       [[ABB]]:
// CHECK:       [[ONE_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 1
// CHECK:       [[ONE:%[0-9]+]] = apply {{%[0-9]+}}([[ONE_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[ONE]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[DEFBB]]({{.*}}):
// CHECK:       [[NESTEDRESULT_STORAGE:%[0-9]+]] = alloc_stack $Int
// CHECK:       [[NESTEDRESULT:%[0-9]+]] = mark_uninitialized [var] [[NESTEDRESULT_STORAGE]] : $*Int
// CHECK:       switch_enum %0 : $E, case #E.b!enumelt: [[BBB:bb[0-9]+]], default [[NESTEDDEFBB:bb[0-9]+]]

// CHECK:       [[BBB]]:
// CHECK:       throw {{%[0-9]+}} : $any Error
//
// CHECK:       [[NESTEDDEFBB]]({{.*}}):
// CHECK:       [[TWO_BUILTIN:%[0-9]+]] = integer_literal $Builtin.IntLiteral, 2
// CHECK:       [[TWO:%[0-9]+]] = apply {{%[0-9]+}}([[TWO_BUILTIN]], {{%[0-9]+}}) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK:       store [[TWO]] to [trivial] [[NESTEDRESULT]] : $*Int
// CHECK:       [[TMP:%[0-9]+]] = load [trivial] [[NESTEDRESULT]] : $*Int
// CHECK:       store [[TMP]] to [trivial] [[RESULT]] : $*Int
// CHECK:       br [[EXITBB:bb[0-9]+]]
//
// CHECK:       [[EXITBB]]:
// CHECK:       [[VAL:%[0-9]+]] = load [trivial] [[RESULT]] : $*Int
// CHECK:       dealloc_stack [[RESULT_STORAGE]] : $*Int
// CHECK:       return [[VAL]] : $Int

func testAssignment() {
  var x = 0
  x = switch Bool.random() { case true: 0 case false: 1 }
  let fn = {
    x = switch Bool.random() { case true: 0 case false: 1 }
  }
}

func nestedType() throws -> Int {
  switch Bool.random() {
  case true:
    struct S: Error {}
    throw S()
  case false:
    0
  }
}
