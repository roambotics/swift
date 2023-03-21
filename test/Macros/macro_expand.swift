// RUN: %empty-directory(%t)
// RUN: %target-build-swift -swift-version 5 -I %swift-host-lib-dir -L %swift-host-lib-dir -emit-library -o %t/%target-library-name(MacroDefinition) -module-name=MacroDefinition %S/Inputs/syntax_macro_definitions.swift -g -no-toolchain-stdlib-rpath -swift-version 5
// RUNx: %target-swift-frontend -dump-ast -enable-experimental-feature FreestandingMacros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir %s -module-name MacroUser 2>&1 | %FileCheck --check-prefix CHECK-AST %s

// Diagnostics testing
// RUN: %target-typecheck-verify-swift -swift-version 5 -enable-experimental-feature FreestandingMacros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -module-name MacroUser -DTEST_DIAGNOSTICS

// RUN: not %target-swift-frontend -swift-version 5 -typecheck -enable-experimental-feature FreestandingMacros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -module-name MacroUser -DTEST_DIAGNOSTICS -serialize-diagnostics-path %t/macro_expand.dia %s -emit-macro-expansion-files no-diagnostics > %t/macro-printing.txt
// RUN: c-index-test -read-diagnostics %t/macro_expand.dia 2>&1 | %FileCheck -check-prefix CHECK-DIAGS %s

// RUN: %FileCheck %s  --check-prefix CHECK-MACRO-PRINTED < %t/macro-printing.txt

// Debug info SIL testing
// RUN: %target-swift-frontend -swift-version 5 -emit-sil -enable-experimental-feature FreestandingMacros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir %s -module-name MacroUser -o - -g | %FileCheck --check-prefix CHECK-SIL %s

// Debug info IR testing
// RUN: %target-swift-frontend -swift-version 5 -emit-ir -enable-experimental-feature FreestandingMacros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir %s -module-name MacroUser -o - -g | %FileCheck --check-prefix CHECK-IR %s

// Execution testing
// RUN: %target-build-swift -swift-version 5 -g -enable-experimental-feature FreestandingMacros -load-plugin-library %t/%target-library-name(MacroDefinition) -I %swift-host-lib-dir -L %swift-host-lib-dir %s -o %t/main -module-name MacroUser
// RUN: %target-run %t/main | %FileCheck %s
// REQUIRES: executable_test

// Plugin search path and loaded module trace testing
// RUN: %target-swift-frontend -swift-version 5 -emit-sil -enable-experimental-feature FreestandingMacros -plugin-path %t -I %swift-host-lib-dir %s -module-name MacroUser -emit-loaded-module-trace -o %t/loaded_module_trace
// RUN: %FileCheck -check-prefix=CHECK-MODULE-TRACE %s < %t/loaded_module_trace.trace.json

// CHECK-MODULE-TRACE: {{libMacroDefinition.dylib|libMacroDefinition.so|MacroDefinition.dll}}

// FIXME: Swift parser is not enabled on Linux CI yet.
// REQUIRES: OS=macosx

#if TEST_DIAGNOSTICS
@freestanding(declaration)
macro NotCovered() = #externalMacro(module: "MacroDefinition", type: "InvalidMacro")

struct MemberNotCovered {
  #NotCovered
  // expected-note@-1 {{in expansion of macro 'NotCovered' here}}

  // CHECK-DIAGS: error: declaration name 'value' is not covered by macro 'NotCovered'
  // CHECK-DIAGS: CONTENTS OF FILE @__swiftmacro_9MacroUser16MemberNotCoveredV0dE0fMf0_.swift
  // CHECK-DIAGS: var value: Int
  // CHECK-DIAGS: END CONTENTS OF FILE
}

@attached(peer)
macro Invalid() = #externalMacro(module: "MacroDefinition", type: "InvalidMacro")

@Invalid
struct Bad {}
// expected-note@-1 18 {{in expansion of macro 'Invalid' here}}

// CHECK-DIAGS: error: macro expansion cannot introduce import
// CHECK-DIAGS: error: macro expansion cannot introduce precedence group
// CHECK-DIAGS: error: macro expansion cannot introduce macro
// CHECK-DIAGS: error: macro expansion cannot introduce extension
// CHECK-DIAGS: error: macro expansion cannot introduce '@main' type
// CHECK-DIAGS: error: declaration name 'MyMain' is not covered by macro 'Invalid'
// CHECK-DIAGS: error: declaration name 'Array' is not covered by macro 'Invalid'
// CHECK-DIAGS: error: declaration name 'Dictionary' is not covered by macro 'Invalid'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type 'BooleanLiteralType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type 'ExtendedGraphemeClusterType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type 'FloatLiteralType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type 'IntegerLiteralType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type 'StringLiteralType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type 'UnicodeScalarType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type '_ColorLiteralType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type '_ImageLiteralType'
// CHECK-DIAGS: error: macro expansion cannot introduce default literal type '_FileReferenceLiteralType'

// CHECK-DIAGS: CONTENTS OF FILE @__swiftmacro_9MacroUser3BadV7InvalidfMp_.swift
// CHECK-DIAGS: import Swift
// CHECK-DIAGS: precedencegroup MyPrecedence {}
// CHECK-DIAGS: @attached(member) macro myMacro()
// CHECK-DIAGS: extension Int {}
// CHECK-DIAGS: @main
// CHECK-DIAGS: struct MyMain {
// CHECK-DIAGS:   static func main() {}
// CHECK-DIAGS: }
// CHECK-DIAGS: typealias Array = Void
// CHECK-DIAGS: typealias Dictionary = Void
// CHECK-DIAGS: typealias BooleanLiteralType = Void
// CHECK-DIAGS: typealias ExtendedGraphemeClusterType = Void
// CHECK-DIAGS: typealias FloatLiteralType = Void
// CHECK-DIAGS: typealias IntegerLiteralType = Void
// CHECK-DIAGS: typealias StringLiteralType = Void
// CHECK-DIAGS: typealias UnicodeScalarType = Void
// CHECK-DIAGS: typealias _ColorLiteralType = Void
// CHECK-DIAGS: typealias _ImageLiteralType = Void
// CHECK-DIAGS: typealias _FileReferenceLiteralType = Void
// CHECK-DIAGS: END CONTENTS OF FILE
#endif

@freestanding(expression) macro customFileID() -> String = #externalMacro(module: "MacroDefinition", type: "FileIDMacro")
@freestanding(expression) macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")
@freestanding(expression) macro fileID<T: ExpressibleByStringLiteral>() -> T = #externalMacro(module: "MacroDefinition", type: "FileIDMacro")
@freestanding(expression) macro recurse(_: Bool) = #externalMacro(module: "MacroDefinition", type: "RecursiveMacro")

func testFileID(a: Int, b: Int) {
  // CHECK: MacroUser/macro_expand.swift
  print("Result is \(#customFileID)")
  // CHECK-SIL: sil_scope [[MACRO_SCOPE:[0-9]+]] { loc "{{.*}}":1:1 parent @$s9MacroUser10testFileID1a1bySi_SitF06customdE0fMf_ {{.*}} }
  // CHECK-SIL: sil_scope [[SRC_SCOPE:[0-9]+]] { loc "{{.*}}macro_expand.swift":[[@LINE-2]]
  // CHECK-SIL: sil_scope {{[0-9]+}} { loc "{{.*}}":1:1 parent [[MACRO_SCOPE]] inlined_at [[SRC_SCOPE]] }
  // CHECK-IR: !DISubprogram(name: "customFileID", linkageName: "$s9MacroUser10testFileID1a1bySi_SitF06customdE0fMf_"


  // CHECK: Builtin result is MacroUser/macro_expand.swift
  // CHECK-AST: macro_expansion_expr type='String'{{.*}}name=line
  print("Builtin result is \(#fileID)")
}

testFileID(a: 1, b: 2)

@freestanding(expression) macro stringifyAndTry<T>(_ value: T) -> (T, String) =
    #externalMacro(module: "MacroDefinition", type: "StringifyAndTryMacro")

func testStringify(a: Int, b: Int) {
  let s = #stringify(a + b)
  print(s)

  // CHECK-AST: macro_expansion_expr type='(Int, String)'{{.*}}name=stringify
  // CHECK-AST-NEXT: argument_list
  // CHECK-AST: tuple_expr type='(Int, String)' location=Macro expansion of #stringify

  let (b, s2) = #stringify({ () -> Bool in return true })
  // CHECK-AST: macro_expansion_expr type='(() -> Bool, String)'{{.*}}name=stringify
  // CHECK-AST-NEXT: argument_list
  // CHECK-AST: tuple_expr type='(() -> Bool, String)' location=Macro expansion of #stringify

  let (b2, s3) = #stringify<Double>(1 + 2)
  // CHECK-AST: macro_expansion_expr type='(Double, String)'{{.*}}name=stringify
  // CHECK-AST-NEXT: argument_list
  // CHECK-AST: tuple_expr type='(Double, String)' location=Macro expansion of #stringify

  _ = (b, b2, s2, s3)
}

public struct Outer {
  var value: Int = 0
  public func test() {
    let (a, b) = #stringify(1 + value)

    let (c, d) = #stringify({ x in
      x + 1
    })

    _ = a
    _ = b
    _ = c
    _ = d
  }
}

// CHECK: (2, "a + b")
testStringify(a: 1, b: 1)

func maybeThrowing() throws -> Int { 5 }

#if TEST_DIAGNOSTICS
@freestanding(expression) @discardableResult
macro discardableStringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

func testDiscardableStringify(x: Int) {
  #stringify(x + 1) // expected-warning{{expression of type '(Int, String)' is unused}}
  #discardableStringify(x + 1)
}
#endif

func testStringifyWithThrows() throws {
  // Okay, we can put the try inside or outside
  _ = try #stringify(maybeThrowing())
  _ = #stringify(try maybeThrowing())

#if TEST_DIAGNOSTICS
  // FIXME: Lots of duplicate notes here
  _ = #stringify(maybeThrowing()) // expected-note 4{{in expansion of macro 'stringify' here}}

    // CHECK-DIAGS: @__swiftmacro_9MacroUser23testStringifyWithThrowsyyKF9stringifyfMf1_.swift:1:2: error: call can throw but is not marked with 'try'
#endif
  
  // The macro adds the 'try' for us.
  _ = #stringifyAndTry(maybeThrowing())
}


@freestanding(expression) macro addBlocker<T>(_ value: T) -> T = #externalMacro(module: "MacroDefinition", type: "AddBlocker")

struct OnlyAdds {
  static func +(lhs: OnlyAdds, rhs: OnlyAdds) -> OnlyAdds { lhs }
}

func testAddBlocker(a: Int, b: Int, c: Int, oa: OnlyAdds) {
  _ = #addBlocker(a * b * c)
#if TEST_DIAGNOSTICS
  _ = #addBlocker(a + b * c) // expected-error{{blocked an add; did you mean to subtract? (from macro 'addBlocker')}}
  // expected-note@-1{{use '-'}}{{21-23=- }}
  _ = #addBlocker(oa + oa) // expected-error{{blocked an add; did you mean to subtract? (from macro 'addBlocker')}}
  // expected-note@-1{{in expansion of macro 'addBlocker' here}}
  // expected-note@-2{{use '-'}}{{22-24=- }}

  // CHECK-DIAGS: @__swiftmacro_9MacroUser14testAddBlocker1a1b1c2oaySi_S2iAA8OnlyAddsVtF03addE0fMf1_.swift:1:4: error: binary operator '-' cannot be applied to two 'OnlyAdds' operands [] []
  // CHECK-DIAGS: CONTENTS OF FILE @__swiftmacro_9MacroUser14testAddBlocker1a1b1c2oaySi_S2iAA8OnlyAddsVtF03addE0fMf1_.swift:
  // CHECK-DIAGS-NEXT: Original source range: {{.*}}macro_expand.swift:[[@LINE-6]]:7 - {{.*}}macro_expand.swift:[[@LINE-6]]:27
  // CHECK-DIAGS-NEXT: oa - oa
  // CHECK-DIAGS-NEXT: END CONTENTS OF FILE

  _ = #addBlocker({ // expected-note{{in expansion of macro 'addBlocker' here}}

      print("hello")
      print(oa + oa) // expected-error{{blocked an add; did you mean to subtract? (from macro 'addBlocker')}}
      // expected-note@-1{{use '-'}}
      print(oa + oa) // expected-error{{blocked an add; did you mean to subtract? (from macro 'addBlocker')}}
      // expected-note@-1{{use '-'}}
    }())

  // Check recursion.
  #recurse(false) // okay
  #recurse(true) // expected-note{{in expansion of macro 'recurse' here}}
#endif
}

@freestanding(expression) macro leftHandOperandFinder<T>(_ value: T) -> T = #externalMacro(module: "MacroDefinition", type: "LeftHandOperandFinderMacro")


// Test source location information.
func testSourceLocations(x: Int, yolo: Int, zulu: Int) {
  // CHECK-MACRO-PRINTED: Source range for LHS is MacroUser/macro_expand.swift: [[@LINE+3]]:5-[[@LINE+3]]:13
  // CHECK-MACRO-PRINTED: Source range for LHS is MacroUser/macro_expand.swift: [[@LINE+2]]:5-[[@LINE+2]]:6
  _ = #leftHandOperandFinder(
    x + yolo + zulu
  )
}

// Make sure we don't crash with declarations produced by expansions.
@freestanding(expression) macro nestedDeclInExpr() -> () -> Void = #externalMacro(module: "MacroDefinition", type: "NestedDeclInExprMacro")

func testNestedDeclInExpr() {
  let _: () -> Void = #nestedDeclInExpr
}

@freestanding(declaration, names: arbitrary) macro bitwidthNumberedStructs(_ baseName: String) = #externalMacro(module: "MacroDefinition", type: "DefineBitwidthNumberedStructsMacro")
// Test overload
@freestanding(declaration, names: arbitrary) macro bitwidthNumberedStructs(_ baseName: String, blah: Bool) = #externalMacro(module: "MacroDefinition", type: "DefineBitwidthNumberedStructsMacro")
// Test non-arbitrary names
@freestanding(declaration, names: named(A), named(B), named(foo), named(addOne))
macro defineDeclsWithKnownNames() = #externalMacro(module: "MacroDefinition", type: "DefineDeclsWithKnownNamesMacro")

// FIXME: Macros producing arbitrary names are not supported yet
#if false
#bitwidthNumberedStructs("MyIntGlobal")

#bitwidthNumberedStructs("MyIntGlobalTwo", blah: false)

let blah = false
#bitwidthNumberedStructs("MyIntGlobalThree", blah: blah)
#endif

// Test unqualified lookup from within a macro expansion
@freestanding(declaration, names: named(StructWithUnqualifiedLookup))
macro structWithUnqualifiedLookup() = #externalMacro(module: "MacroDefinition", type: "DefineStructWithUnqualifiedLookupMacro")

@freestanding(declaration)
macro anonymousTypes(_: () -> String) = #externalMacro(module: "MacroDefinition", type: "DefineAnonymousTypesMacro")


// FIXME: Global freestanding macros not yet supported in script mode.
#if false
let world = 3 // to be used by the macro expansion below
#structWithUnqualifiedLookup()
_ = StructWithUnqualifiedLookup().foo()

#anonymousTypes { "hello" }
#endif

func testFreestandingMacroExpansion() {
  // Explicit structs to force macros to be parsed as decl.
  struct Foo {
    #bitwidthNumberedStructs("MyIntOne")
  }

  // CHECK: MyIntOne8
  print(Foo.MyIntOne8.self)
  // CHECK: MyIntOne16
  print(Foo.MyIntOne16.self)
  // CHECK: MyIntOne32
  print(Foo.MyIntOne32.self)
  // CHECK: MyIntOne64
  print(Foo.MyIntOne64.self)

  struct Foo2 {
    #bitwidthNumberedStructs("MyIntTwo", blah: false)
    #defineDeclsWithKnownNames()
  }
  // CHECK: MyIntTwo8
  print(Foo2.MyIntTwo8.self)
  // CHECK: MyIntTwo16
  print(Foo2.MyIntTwo16.self)
  // CHECK: MyIntTwo32
  print(Foo2.MyIntTwo32.self)
  // CHECK: MyIntTwo64
  print(Foo2.MyIntTwo64.self)
  // CHECK: A
  print(Foo2.A.self)
  // CHECK: B
  print(Foo2.B.self)
  // CHECK: 1
  print(Foo2().foo)
  // CHECK: 2
  print(Foo2().addOne(1))

  #if TEST_DIAGNOSTICS
  struct Foo3 {
    #bitwidthNumberedStructs("BUG", blah: false)
    // expected-note@-1 4{{in expansion of macro 'bitwidthNumberedStructs' here}}
    // CHECK-DIAGS: CONTENTS OF FILE @__swiftmacro_9MacroUser016testFreestandingA9ExpansionyyF4Foo3L_V23bitwidthNumberedStructsfMf0_.swift
    // CHECK-DIAGS: struct BUG {
    // CHECK-DIAGS:   func $s9MacroUser016testFreestandingA9ExpansionyyF4Foo3L_V23bitwidthNumberedStructsfMf0_6methodfMu_()
    // CHECK-DIAGS:   func $s9MacroUser016testFreestandingA9ExpansionyyF4Foo3L_V23bitwidthNumberedStructsfMf0_6methodfMu0{{_?}}()
  }
  #endif

  // FIXME: Arbitrary name lookup is not yet supported.
  // HECK: MyIntGlobal8
  // print(MyIntGlobal8.self)
  // HECK: MyIntGlobal16
  // print(MyIntGlobal16.self)
  // HECK: MyIntGlobal32
  // print(MyIntGlobal32.self)
  // HECK: MyIntGlobal64
  // print(MyIntGlobal64.self)

  #anonymousTypes { "hello" }
}
testFreestandingMacroExpansion()
