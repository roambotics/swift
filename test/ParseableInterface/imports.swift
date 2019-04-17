// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module -o %t/empty.swiftmodule %S/../Inputs/empty.swift
// RUN: %target-swift-frontend -typecheck -emit-parseable-module-interface-path - %s %S/Inputs/imports-other.swift -I %S/Inputs/imports-clang-modules/ -I %t -verify | %FileCheck -implicit-check-not BAD %s


@_exported import empty
import B.B2
import func C.c // expected-warning {{scoped imports are not yet supported in module interfaces}}
import D
@_implementationOnly import Secret_BAD

@_implementationOnly import NotSoSecret
import NotSoSecret2

// CHECK-NOT: import
// CHECK: {{^}}import A{{$}}
// CHECK-NEXT: {{^}}import B{{$}}
// CHECK-NEXT: {{^}}import B.B2{{$}}
// CHECK-NEXT: {{^}}import B.B3{{$}}
// CHECK-NEXT: {{^}}import C/*.c*/{{$}}
// CHECK-NEXT: {{^}}import D{{$}}
// CHECK-NEXT: {{^}}import NotSoSecret{{$}}
// CHECK-NEXT: {{^}}import NotSoSecret2{{$}}
// CHECK-NEXT: {{^}}import Swift{{$}}
// CHECK-NEXT: {{^}}@_exported import empty{{$}}
// CHECK-NOT: import
