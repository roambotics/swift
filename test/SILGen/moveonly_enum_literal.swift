// RUN: %target-swift-frontend -emit-silgen %s | %FileCheck %s

// This test makes sure that we properly setup enums when we construct moveonly
// enums from literals.

@_moveOnly
enum MoveOnlyIntPair {
case lhs(Int)
case rhs(Int)
}

func consumeMoveIntPair(_ x: __owned MoveOnlyIntPair) {}

var value: Bool { false }

// CHECK-LABEL: sil hidden [ossa] @$s21moveonly_enum_literal4testyyF : $@convention(thin) () -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[VALUE:%.*]] = enum $MoveOnlyIntPair, #MoveOnlyIntPair.lhs!enumelt,
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: store [[VALUE]] to [init] [[PROJECT]]
//
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[MARKED_VALUE:%.*]] = mark_must_check [assignable_but_not_consumable] [[PROJECT]]
// CHECK: } // end sil function '$s21moveonly_enum_literal4testyyF'
func test() {
    let x = MoveOnlyIntPair.lhs(5)
    if value {
        consumeMoveIntPair(x)
    }
}
