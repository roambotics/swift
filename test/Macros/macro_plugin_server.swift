// FIXME: Swift parser is not enabled on Linux CI yet.
// REQUIRES: OS=macosx

// RUN: %empty-directory(%t)
// RUN: %empty-directory(%t/plugins)
//
//== Build the plugin library
// RUN: %target-build-swift \
// RUN:   -swift-version 5 \
// RUN:   -I %swift-host-lib-dir \
// RUN:   -L %swift-host-lib-dir \
// RUN:   -emit-library \
// RUN:   -o %t/plugins/%target-library-name(MacroDefinition) \
// RUN:   -module-name=MacroDefinition \
// RUN:   %S/Inputs/syntax_macro_definitions.swift \
// RUN:   -g -no-toolchain-stdlib-rpath

// RUN: %swift-target-frontend \
// RUN:   -typecheck -verify \
// RUN:   -swift-version 5 \
// RUN:   -external-plugin-path %t/plugins#%swift-plugin-server \
// RUN:   -dump-macro-expansions \
// RUN:   %s \
// RUN:   2>&1 | tee %t/macro-expansions.txt

// RUN: %FileCheck -strict-whitespace %s < %t/macro-expansions.txt


@freestanding(expression) macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

func testStringify(a: Int, b: Int) {
  let s: String = #stringify(a + b).1
  print(s)
}

// CHECK:      {{^}}------------------------------
// CHECK-NEXT: {{^}}(a + b, "a + b")
// CHECK-NEXT: {{^}}------------------------------

