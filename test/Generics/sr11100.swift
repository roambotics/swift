// RUN: %target-typecheck-verify-swift -debug-generic-signatures -requirement-machine-protocol-signatures=on 2>&1 | %FileCheck %s

protocol P1 {
  associatedtype A
}

protocol P2 {
  associatedtype C: P1
}

// CHECK: sr11100.(file).Q@
// CHECK-NEXT: Requirement signature: <Self where Self.[Q]X == Self.[Q]X.[P1]A, Self.[Q]Y : P2, Self.[Q]X.[P1]A == Self.[Q]Y.[P2]C>
protocol Q {
  associatedtype X
  associatedtype Y : P2 where X == X.A, X.A == Y.C
}
