// REQUIRES: rdar104716322

// RUN: %target-swift-emit-silgen %s -enable-experimental-feature VariadicGenerics | %FileCheck %s

// Experimental features require an asserts compiler
// REQUIRES: asserts

// XFAIL: OS=windows-msvc

// CHECK-LABEL: sil [ossa] @$s19pack_expansion_type16variadicFunction1t1ux_q_txQp_txxQp_q_xQptq_Rhzr0_lF : $@convention(thin) <T..., U... where ((T, U)...) : Any> (@pack_guaranteed Pack{repeat each T}, @pack_guaranteed Pack{repeat each U}) -> @pack_out Pack{repeat (each T, each U)} {
// CHECK: bb0(%0 : $*Pack{repeat (each T, each U)}, %1 : $*Pack{repeat each T}, %2 : $*Pack{repeat each U}):
public func variadicFunction<T..., U...>(t: repeat each T, u: repeat each U) -> (repeat (each T, each U)) {}

public struct VariadicType<T...> {
  // CHECK-LABEL: sil [ossa] @$s19pack_expansion_type12VariadicTypeV14variadicMethod1t1ux_qd__txQp_txxQp_qd__xQptqd__RhzlF : $@convention(method) <T...><U... where ((T, U)...) : Any> (@pack_guaranteed Pack{repeat each T}, @pack_guaranteed Pack{repeat each U}, VariadicType<repeat each T>) -> @pack_out Pack{repeat (each T, each U)} {
  // CHECK: bb0(%0 : $*Pack{repeat (each T, each U)}, %1 : $*Pack{repeat each T}, %2 : $*Pack{repeat each U}, %3 : $VariadicType<repeat each T>):
  public func variadicMethod<U...>(t: repeat each T, u: repeat each U) -> (repeat (each T, each U)) {}

  // CHECK-LABEL: sil [ossa] @$s19pack_expansion_type12VariadicTypeV13takesFunction1tyqd__qd__Qp_txxQpXE_tlF : $@convention(method) <T...><U...> (@noescape @callee_guaranteed @substituted <τ_0_0..., τ_0_1..., τ_0_2..., τ_0_3...> (@pack_guaranteed Pack{repeat each τ_0_0}) -> @pack_out Pack{repeat each τ_0_2} for <T, T, U, U>, VariadicType<repeat each T>) -> () {
  // CHECK: bb0(%0 : $@noescape @callee_guaranteed @substituted <τ_0_0..., τ_0_1..., τ_0_2..., τ_0_3...> (@pack_guaranteed Pack{repeat each τ_0_0}) -> @pack_out Pack{repeat each τ_0_2} for <T, T, U, U>, %1 : $VariadicType<repeat each T>):
  public func takesFunction<U...>(t: (repeat each T) -> (repeat each U)) {}
}

// CHECK-LABEL: sil hidden [ossa] @$s19pack_expansion_type17variadicMetatypesyyxxQplF : $@convention(thin) <T...> (@pack_guaranteed Pack{repeat each T}) -> () {
// CHECK: bb0(%0 : $*Pack{repeat each T}):
// CHECK: metatype $@thin VariadicType<>.Type
// CHECK: metatype $@thin VariadicType<Int>.Type
// CHECK: metatype $@thin VariadicType<Int, String>.Type
// CHECK: metatype $@thin VariadicType<repeat each T>.Type
// CHECK: metatype $@thin VariadicType<Int, repeat Array<each T>>.Type
// CHECK: metatype $@thin (repeat each T).Type
// CHECK: metatype $@thin (Int, repeat Array<each T>).Type
// CHECK: metatype $@thin ((repeat each T) -> ()).Type
// CHECK: metatype $@thin ((Int, repeat Array<each T>) -> ()).Type
// CHECK: return

func variadicMetatypes<T...>(_: repeat each T) {
  _ = VariadicType< >.self
  _ = VariadicType<Int>.self
  _ = VariadicType<Int, String>.self
  _ = VariadicType<repeat each T>.self
  _ = VariadicType<Int, repeat Array<each T>>.self
  _ = (repeat each T).self
  _ = (Int, repeat Array<each T>).self
  _ = ((repeat each T) -> ()).self
  _ = ((Int, repeat Array<each T>) -> ()).self
}
