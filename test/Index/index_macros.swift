// RUN: %empty-directory(%t)
// RUN: %target-swift-ide-test -print-indexed-symbols -source-filename %s -enable-experimental-feature Macros | %FileCheck %s
// REQUIRES: OS=macosx


@freestanding(expression) macro myLine() -> Int = #externalMacro(module: "MacroDefinition", type: "LineMacro")
@freestanding(expression) macro myFilename<T: ExpressibleByStringLiteral>() -> T = #externalMacro(module: "MacroDefinition", type: "FileMacro")
@freestanding(expression) macro myStringify<T>(_: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

func test(x: Int) {
  _ = #myLine
  let _: String = #myFilename
  _ = #myStringify(x + x)
}

// CHECK: 6:33 | macro/Swift | myLine() | s:14swift_ide_test6myLineSiycfm | Def | rel: 0
// CHECK: 6:45 | struct/Swift | Int | s:Si | Ref | rel: 0
// CHECK: 7:33 | macro/Swift | myFilename() | s:14swift_ide_test10myFilenamexycfm | Def | rel: 0
// CHECK: 7:47 | protocol/Swift | ExpressibleByStringLiteral | s:s26ExpressibleByStringLiteralP | Ref | rel: 0
// CHECK: 8:33 | macro/Swift | myStringify(_:) | s:14swift_ide_test11myStringifyyx_SStxcfm | Def | rel: 0

// CHECK: 11:8 | macro/Swift | myLine() | s:14swift_ide_test6myLineSiycfm | Ref,RelCont | rel: 1
// CHECK: 12:20 | macro/Swift | myFilename() | s:14swift_ide_test10myFilenamexycfm | Ref,RelCont | rel: 1
// CHECK: 13:8 | macro/Swift | myStringify(_:) | s:14swift_ide_test11myStringifyyx_SStxcfm | Ref,RelCont | rel: 1
// CHECK: 13:20 | param/Swift | x | s:14swift_ide_test0C01xySi_tFACL_Sivp | Ref,Read,RelCont | rel: 1
// CHECK: 13:22 | static-method/infix-operator/Swift | +(_:_:) | s:Si1poiyS2i_SitFZ | Ref,Call,RelCall,RelCont | rel: 1
// CHECK: 13:24 | param/Swift | x | s:14swift_ide_test0C01xySi_tFACL_Sivp | Ref,Read,RelCont | rel: 1
