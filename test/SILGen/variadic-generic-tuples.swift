// RUN: %target-swift-emit-silgen -enable-experimental-feature VariadicGenerics %s | %FileCheck %s

// Because of -enable-experimental-feature VariadicGenerics
// REQUIRES: asserts

func takeAny(_ arg: Any) {}

// CHECK-LABEL: @$s4main16testIgnoredTupleyyxxQpRvzlF : $@convention(thin) <each T> (@pack_guaranteed Pack{repeat each T}) -> () {
// CHECK:       bb0(%0 : $*Pack{repeat each T}):
// CHECK-NEXT:    debug_value
// CHECK-NEXT:    [[ZERO:%.*]] = integer_literal $Builtin.Word, 0
// CHECK-NEXT:    [[ONE:%.*]] = integer_literal $Builtin.Word, 1
// CHECK-NEXT:    [[LEN:%.*]] = pack_length $Pack{repeat each T}
// CHECK-NEXT:    br bb1([[ZERO]] : $Builtin.Word)
// CHECK:       bb1([[IDX:%.*]] : $Builtin.Word)
// CHECK-NEXT:    [[IDX_EQ_LEN:%.*]] = builtin "cmp_eq_Word"([[IDX]] : $Builtin.Word, [[LEN]] : $Builtin.Word) : $Builtin.Int1
// CHECK-NEXT:     cond_br [[IDX_EQ_LEN]], bb3, bb2
// CHECK:       bb2:
// CHECK-NEXT:    [[INDEX:%.*]] = dynamic_pack_index [[IDX]] of $Pack{repeat ()}
// CHECK-NEXT:    open_pack_element [[INDEX]] of <each T> at <Pack{repeat each T}>, shape $T, uuid [[UUID:".*"]]
// CHECK-NEXT:    [[TEMP:%.*]] = alloc_stack $Any
// CHECK-NEXT:    [[ELT_ADDR:%.*]] = pack_element_get [[INDEX]] of %0 : $*Pack{repeat each T} as $*@pack_element([[UUID]]) T
// CHECK-NEXT:    [[TEMP_AS_T:%.*]] = init_existential_addr [[TEMP]] : $*Any, $@pack_element([[UUID]]) T
// CHECK-NEXT:    copy_addr [[ELT_ADDR]] to [init] [[TEMP_AS_T]] : $*@pack_element([[UUID]]) T
// CHECK-NEXT:    // function_ref
// CHECK-NEXT:    [[FN:%.*]] = function_ref @$s4main7takeAnyyyypF
// CHECK-NEXT:    apply [[FN]]([[TEMP]])
// CHECK-NEXT:    destroy_addr [[TEMP]] : $*Any
// CHECK-NEXT:    dealloc_stack [[TEMP]] : $*Any
// CHECK-NEXT:    [[NEXT_IDX:%.*]] = builtin "add_Word"([[IDX]] : $Builtin.Word, [[ONE]] : $Builtin.Word) : $Builtin.Word
// CHECK-NEXT:    br bb1([[NEXT_IDX]] : $Builtin.Word)
// CHECK:       bb3:
// CHECK-NEXT:    [[RET:%.*]] = tuple ()
// CHECK-NEXT:    return [[RET]] : $()
func testIgnoredTuple<each T>(_ args: repeat each T) {
  (repeat takeAny(each args))
}

public struct Stored<Value> {}

public struct Container<each T> {
  public var storage: (repeat Stored<each T>)

  public init() {
    self.storage = (repeat Stored<each T>())
  }
}

//   Getter for Container.storage
// CHECK-LABEL: sil {{.*}}@$s4main9ContainerV7storageAA6StoredVyxGxQp_tvg
// CHECK-SAME:    $@convention(method) <each T> (@in_guaranteed Container<repeat each T>) -> @pack_out Pack{repeat Stored<each T>}
// CHECK:         [[FIELD:%.*]] = struct_element_addr %1 : $*Container<repeat each T>, #Container.storage
//   Copy the field into a temporary for some reason?
// CHECK-NEXT:    [[FIELD_COPY:%.*]] = alloc_stack $(repeat Stored<each T>)
// CHECK-NEXT:    copy_addr [[FIELD]] to [init] [[FIELD_COPY]] : $*(repeat Stored<each T>)
//   Pack loop to copy into the @pack_out parameter.
// CHECK-NEXT:    [[ZERO:%.*]] = integer_literal $Builtin.Word, 0
// CHECK-NEXT:    [[ONE:%.*]] = integer_literal $Builtin.Word, 1
// CHECK-NEXT:    [[LEN:%.*]] = pack_length $Pack{repeat each T}
// CHECK-NEXT:    br bb1([[ZERO]] : $Builtin.Word)
// CHECK:       bb1([[IDX:%.*]] : $Builtin.Word)
// CHECK-NEXT:    [[IDX_EQ_LEN:%.*]] = builtin "cmp_eq_Word"([[IDX]] : $Builtin.Word, [[LEN]] : $Builtin.Word) : $Builtin.Int1
// CHECK-NEXT:     cond_br [[IDX_EQ_LEN]], bb3, bb2
// CHECK:       bb2:
// CHECK-NEXT:    [[INDEX:%.*]] = dynamic_pack_index [[IDX]] of $Pack{repeat Stored<each T>}
// CHECK-NEXT:    open_pack_element [[INDEX]] of <each T> at <Pack{repeat each T}>, shape $T, uuid [[UUID:".*"]]
// CHECK-NEXT:    [[OUT_ELT_ADDR:%.*]] = pack_element_get [[INDEX]] of %0 : $*Pack{repeat Stored<each T>} as $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    [[FIELD_ELT_ADDR:%.*]] = tuple_pack_element_addr [[INDEX]] of [[FIELD_COPY]] : $*(repeat Stored<each T>) as $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    [[ELT_VALUE:%.*]] = load [trivial] [[FIELD_ELT_ADDR]] : $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    store [[ELT_VALUE]] to [trivial] [[OUT_ELT_ADDR]] : $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    [[NEXT_IDX:%.*]] = builtin "add_Word"([[IDX]] : $Builtin.Word, [[ONE]] : $Builtin.Word) : $Builtin.Word
// CHECK-NEXT:    br bb1([[NEXT_IDX]] : $Builtin.Word)
// CHECK:       bb3:
//   Clean up.
// CHECK-NEXT:    dealloc_stack [[FIELD_COPY]] : $*(repeat Stored<each T>)
// CHECK-NEXT:    [[RET:%.*]] = tuple ()
// CHECK-NEXT:    return [[RET]] : $()

//   Setter for Container.storage
// CHECK-LABEL: sil {{.*}}@$s4main9ContainerV7storageAA6StoredVyxGxQp_tvs
// CHECK-SAME:    $@convention(method) <each T> (@pack_owned Pack{repeat Stored<each T>}, @inout Container<repeat each T>) -> () 
//   Materialize the pack into a local tuple.
// CHECK:         [[ARG_COPY:%.*]] = alloc_stack $(repeat Stored<each T>), let,
// CHECK-NEXT:    [[ZERO:%.*]] = integer_literal $Builtin.Word, 0
// CHECK-NEXT:    [[ONE:%.*]] = integer_literal $Builtin.Word, 1
// CHECK-NEXT:    [[LEN:%.*]] = pack_length $Pack{repeat each T}
// CHECK-NEXT:    br bb1([[ZERO]] : $Builtin.Word)
// CHECK:       bb1([[IDX:%.*]] : $Builtin.Word)
// CHECK-NEXT:    [[IDX_EQ_LEN:%.*]] = builtin "cmp_eq_Word"([[IDX]] : $Builtin.Word, [[LEN]] : $Builtin.Word) : $Builtin.Int1
// CHECK-NEXT:     cond_br [[IDX_EQ_LEN]], bb3, bb2
// CHECK:       bb2:
// CHECK-NEXT:    [[INDEX:%.*]] = dynamic_pack_index [[IDX]] of $Pack{repeat Stored<each T>}
// CHECK-NEXT:    open_pack_element [[INDEX]] of <each T> at <Pack{repeat each T}>, shape $T, uuid [[UUID:".*"]]
// CHECK-NEXT:    [[ARG_COPY_ELT_ADDR:%.*]] = tuple_pack_element_addr [[INDEX]] of [[ARG_COPY]] : $*(repeat Stored<each T>) as $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    [[PACK_ELT_ADDR:%.*]] = pack_element_get [[INDEX]] of %0 : $*Pack{repeat Stored<each T>} as $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    [[ELT_VALUE:%.*]] = load [trivial] [[PACK_ELT_ADDR]] : $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    store [[ELT_VALUE]] to [trivial] [[ARG_COPY_ELT_ADDR]] : $*Stored<@pack_element([[UUID]]) T>
// CHECK-NEXT:    [[NEXT_IDX:%.*]] = builtin "add_Word"([[IDX]] : $Builtin.Word, [[ONE]] : $Builtin.Word) : $Builtin.Word
// CHECK-NEXT:    br bb1([[NEXT_IDX]] : $Builtin.Word)
// CHECK:       bb3:
// CHECK-NEXT:    debug_value
//   Copy the local tuple for some reason?
// CHECK-NEXT:    [[COPY2:%.*]] = alloc_stack $(repeat Stored<each T>)
// CHECK-NEXT:    copy_addr [[ARG_COPY]] to [init] [[COPY2]] : $*(repeat Stored<each T>)
//   Finally, the actual assignment.
// CHECK-NEXT:    [[ACCESS:%.*]] = begin_access [modify] [unknown] %1 :
// CHECK-NEXT:    [[FIELD:%.*]] = struct_element_addr [[ACCESS]] : $*Container<repeat each T>, #Container.storage
// CHECK-NEXT:    copy_addr [take] [[COPY2]] to [[FIELD]] : $*(repeat Stored<each T>)
// CHECK-NEXT:    end_access [[ACCESS]]
//   Clean up.
// CHECK-NEXT:    dealloc_stack [[COPY2]]
// CHECK-NEXT:    dealloc_stack [[ARG_COPY]]
// CHECK-NEXT:    [[RET:%.*]] = tuple ()
// CHECK-NEXT:    return [[RET]] : $()

// CHECK-LABEL: sil {{.*}}@$s4main9ContainerV7storageAA6StoredVyxGxQp_tvM

struct Wrapper<Value> {
  let value: Value
}

// CHECK-LABEL: @$s4main17wrapTupleElementsyAA7WrapperVyxGxQp_txxQpRvzlF : $@convention(thin) <each T> (@pack_guaranteed Pack{repeat each T}) -> @pack_out Pack{repeat Wrapper<each T>}
func wrapTupleElements<each T>(_ value: repeat each T) -> (repeat Wrapper<each T>) {
  // CHECK: [[RETURN_VAL:%.*]] : $*Pack{repeat Wrapper<each T>}

  // CHECK: [[VAR:%.*]] = alloc_stack [lexical] $(repeat each T)
  let values = (repeat each value)

  // Create a temporary for the 'values' in 'each values.element'
  // CHECK: bb3:
  // CHECK-NEXT: [[TEMP:%.*]] = alloc_stack $(repeat each T)
  // CHECK-NEXT: copy_addr [[VAR]] to [init] [[TEMP]] : $*(repeat each T)

  // Integer values for dynamic pack loop
  // CHECK-NEXT: [[ZERO:%.*]] = integer_literal $Builtin.Word, 0
  // CHECK-NEXT: [[ONE:%.*]] = integer_literal $Builtin.Word, 1
  // CHECK-NEXT: [[PACK_LEN:%.*]] = pack_length $Pack{repeat each T}
  // CHECK-NEXT: br bb4([[ZERO]] : $Builtin.Word)

  // Loop condition
  // CHECK: bb4([[INDEX:%.*]] : $Builtin.Word)
  // CHECK-NEXT: [[INDEX_EQ_LEN:%.*]] = builtin "cmp_eq_Word"([[INDEX]] : $Builtin.Word, [[PACK_LEN]] : $Builtin.Word) : $Builtin.Int1
  // CHECK-NEXT: cond_br [[INDEX_EQ_LEN]], bb6, bb5

  // Loop body
  // CHECK: bb5:
  // CHECK-NEXT: [[CUR_INDEX:%.*]] = dynamic_pack_index [[INDEX]] of $Pack{repeat Wrapper<each T>}
  // CHECK-NEXT: open_pack_element [[CUR_INDEX]] of <each T> at <Pack{repeat each T}>, shape $T, uuid [[UUID:".*"]]
  // CHECK-NEXT: [[RETURN_VAL_ELT_ADDR:%.*]] = pack_element_get [[CUR_INDEX]] of [[RETURN_VAL]] : $*Pack{repeat Wrapper<each T>} as $*Wrapper<@pack_element([[UUID]]) T>
  // CHECK-NEXT: [[METATYPE:%.*]] = metatype $@thin Wrapper<@pack_element([[UUID]]) T>.Type
  // CHECK-NEXT: [[TUPLE_ELT_ADDR:%.*]] = tuple_pack_element_addr [[CUR_INDEX]] of [[TEMP]] : $*(repeat each T) as $*@pack_element([[UUID]]) T
  // CHECK-NEXT: [[INIT_ARG:%.*]] = alloc_stack $@pack_element([[UUID]]) T
  // CHECK-NEXT: copy_addr [[TUPLE_ELT_ADDR]] to [init] [[INIT_ARG]] : $*@pack_element([[UUID]]) T
  // function_ref Wrapper.init(value:)
  // CHECK: [[INIT:%.*]] = function_ref @$s4main7WrapperV5valueACyxGx_tcfC : $@convention(method) <τ_0_0> (@in τ_0_0, @thin Wrapper<τ_0_0>.Type) -> @out Wrapper<τ_0_0>
  // CHECK-NEXT: apply [[INIT]]<@pack_element([[UUID]]) T>([[RETURN_VAL_ELT_ADDR]], [[INIT_ARG]], [[METATYPE]]) : $@convention(method) <τ_0_0> (@in τ_0_0, @thin Wrapper<τ_0_0>.Type) -> @out Wrapper<τ_0_0>
  // CHECK-NEXT: dealloc_stack [[INIT_ARG]] : $*@pack_element([[UUID]]) T
  // CHECK-NEXT: [[NEXT_INDEX:%.*]] = builtin "add_Word"([[INDEX]] : $Builtin.Word, [[ONE]] : $Builtin.Word) : $Builtin.Word
  // CHECK-NEXT: br bb4([[NEXT_INDEX]] : $Builtin.Word)

  return (repeat Wrapper(value: each values.element))

  // CHECK: destroy_addr [[TEMP]] : $*(repeat each T)
  // CHECK: dealloc_stack [[TEMP]] : $*(repeat each T)
  // CHECK: destroy_addr [[VAR]] : $*(repeat each T)
  // CHECK: dealloc_stack [[VAR]] : $*(repeat each T)
  // CHECK-NEXT:    [[RET:%.*]] = tuple ()
  // CHECK-NEXT:    return [[RET]] : $()
}

// CHECK-LABEL: sil hidden [ossa] @$s4main20projectTupleElementsyyAA7WrapperVyxGxQpRvzlF : $@convention(thin) <each T> (@pack_guaranteed Pack{repeat Wrapper<each T>}) -> () {
func projectTupleElements<each T>(_ value: repeat Wrapper<each T>) {
  // CHECK: [[VAR:%.*]] = alloc_stack [lexical] $(repeat each T)

  // CHECK-NEXT: [[ZERO:%.*]] = integer_literal $Builtin.Word, 0
  // CHECK-NEXT: [[ONE:%.*]] = integer_literal $Builtin.Word, 1
  // CHECK-NEXT: [[PACK_LEN:%.*]] = pack_length $Pack{repeat each T}

  // CHECK-NEXT: br bb1([[ZERO]] : $Builtin.Word)

  // CHECK: bb1([[INDEX:%.*]] : $Builtin.Word):
  // CHECK-NEXT: [[INDEX_EQ_LEN:%.*]] = builtin "cmp_eq_Word"([[INDEX]] : $Builtin.Word, [[PACK_LEN]] : $Builtin.Word)
  // CHECK-NEXT: cond_br [[INDEX_EQ_LEN]], bb3, bb2

  // CHECK: bb2:
  // CHECK-NEXT: [[CUR_INDEX:%.*]] = dynamic_pack_index [[INDEX]] of $Pack{repeat each T}
  // CHECK-NEXT: open_pack_element [[CUR_INDEX]] of <each T> at <Pack{repeat each T}>, shape $T, uuid "[[UUID:[0-9A-F-]*]]"
  // CHECK-NEXT: [[TUPLE_ELT_ADDR:%.*]] = tuple_pack_element_addr [[CUR_INDEX]] of [[VAR]] : $*(repeat each T) as $*@pack_element("[[UUID]]") T
  // CHECK-NEXT: [[VAL_ELT_ADDR:%.*]] = pack_element_get [[CUR_INDEX]] of %0 : $*Pack{repeat Wrapper<each T>} as $*Wrapper<@pack_element("[[UUID]]") T>
  // CHECK-NEXT: [[TEMP:%.*]] = alloc_stack $Wrapper<@pack_element("[[UUID]]") T>
  // CHECK-NEXT: copy_addr [[VAL_ELT_ADDR]] to [init] [[TEMP]] : $*Wrapper<@pack_element("[[UUID]]") T>
  // CHECK-NEXT: [[MEMBER:%.*]] = struct_element_addr [[TEMP]] : $*Wrapper<@pack_element("[[UUID]]") T>, #Wrapper.value
  // CHECK-NEXT: copy_addr [[MEMBER]] to [init] [[TUPLE_ELT_ADDR]] : $*@pack_element("[[UUID]]") T
  // CHECK-NEXT: destroy_addr [[TEMP]] : $*Wrapper<@pack_element("[[UUID]]") T>
  // CHECK-NEXT: dealloc_stack [[TEMP]] : $*Wrapper<@pack_element("[[UUID]]") T>
  // CHECK-NEXT: [[NEXT_INDEX:%.*]] = builtin "add_Word"([[INDEX]] : $Builtin.Word, [[ONE]] : $Builtin.Word) : $Builtin.Word
  // CHECK-NEXT: br bb1([[NEXT_INDEX]] : $Builtin.Word)

  // CHECK: bb3:
  // CHECK-NEXT: destroy_addr [[VAR]] : $*(repeat each T)
  // CHECK-NEXT: dealloc_stack [[VAR]] : $*(repeat each T)
  // CHECK-NEXT: [[RET:%.*]] = tuple ()
  // CHECK-NEXT: return [[RET]] : $()

  let tuple = (repeat (each value).value)
}
