// RUN: %target-typecheck-verify-swift -enable-experimental-feature NonescapableTypes -enable-experimental-feature NoncopyableGenerics
// REQUIRES: asserts

struct BufferView : ~Escapable, ~Copyable {
  let ptr: UnsafeRawBufferPointer?
  let c: Int
  @_unsafeNonescapableResult
  init(_ ptr: UnsafeRawBufferPointer?, _ c: Int) {
    self.ptr = ptr
    self.c = c
  }
}

struct ImplicitInit1 : ~Escapable { // expected-error{{cannot infer lifetime dependence on implicit initializer, no parameters found that are ~Escapable or Escapable with a borrowing ownership}}
  let ptr: UnsafeRawBufferPointer
}

struct ImplicitInit2 : ~Escapable, ~Copyable {
  let mbv: BufferView
}

struct ImplicitInit3 : ~Escapable, ~Copyable { // expected-error{{cannot infer lifetime dependence on implicit initializer, multiple parameters qualifiy as a candidate}}
  let mbv1: BufferView
  let mbv2: BufferView
}

func foo() -> BufferView { // expected-error{{cannot infer lifetime dependence , no parameters found that are ~Escapable or Escapable with a borrowing ownership}}
  return BufferView(nil, 0)
}

