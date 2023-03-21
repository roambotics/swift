// RUN: %empty-directory(%t)
// RUN: %target-build-swift -swift-version 5 -I %swift-host-lib-dir -L %swift-host-lib-dir -emit-library -o %t/%target-library-name(MacroDefinition) -module-name=MacroDefinition %S/Inputs/syntax_macro_definitions.swift -g -no-toolchain-stdlib-rpath
// RUN: %target-swift-frontend -swift-version 5 -typecheck -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir %s -disable-availability-checking -dump-macro-expansions > %t/expansions-dump.txt 2>&1
// RUN: %FileCheck -check-prefix=CHECK-DUMP %s < %t/expansions-dump.txt
// RUN: %target-typecheck-verify-swift -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -module-name MacroUser -DTEST_DIAGNOSTICS -swift-version 5
// RUN: %target-build-swift -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -L %swift-host-lib-dir %s -o %t/main -module-name MacroUser -swift-version 5
// RUN: %target-run %t/main | %FileCheck %s
// REQUIRES: executable_test

// FIXME: Swift parser is not enabled on Linux CI yet.
// REQUIRES: OS=macosx

@attached(conformance)
macro Equatable() = #externalMacro(module: "MacroDefinition", type: "EquatableMacro")

@attached(conformance)
macro Hashable() = #externalMacro(module: "MacroDefinition", type: "HashableMacro")

func requireEquatable(_ value: some Equatable) {
  print(value == value)
}

func requireHashable(_ value: some Hashable) {
  print(value.hashValue)
}

@Equatable
struct S {}

@Hashable
struct S2 {}

// CHECK-DUMP: @__swiftmacro_25macro_expand_conformances1SV9EquatablefMc_.swift
// CHECK-DUMP: extension S : Equatable  {}

// CHECK: true
requireEquatable(S())

requireEquatable(S2())
requireHashable(S2())

@attached(conformance)
@attached(member, names: named(requirement))
macro DelegatedConformance() = #externalMacro(module: "MacroDefinition", type: "DelegatedConformanceMacro")

protocol P {
  static func requirement()
}

struct Wrapped: P {
  static func requirement() {
    print("Wrapped.requirement")
  }
}

@DelegatedConformance
struct Generic<Element> {}

// CHECK-DUMP: @__swiftmacro_25macro_expand_conformances7GenericV20DelegatedConformancefMc_.swift
// CHECK-DUMP: extension Generic : P where Element: P {}

func requiresP(_ value: (some P).Type) {
  value.requirement()
}

// CHECK: Wrapped.requirement
requiresP(Generic<Wrapped>.self)
