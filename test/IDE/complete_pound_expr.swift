// RUN: %target-swift-ide-test -code-completion -source-filename %s -code-completion-token=POUND_EXPR_1 | %FileCheck %s -check-prefix=POUND_EXPR_INTCONTEXT
// RUN: %target-swift-ide-test -code-completion -source-filename %s -code-completion-token=POUND_EXPR_2 | %FileCheck %s -check-prefix=POUND_EXPR_STRINGCONTEXT
// RUN: %target-swift-ide-test -code-completion -source-filename %s -code-completion-token=POUND_EXPR_3 | %FileCheck %s -check-prefix=POUND_EXPR_SELECTORCONTEXT
// REQUIRES: objc_interop

import ObjectiveC

func useInt(_ str: Int) -> Bool {}
func useString(_ str: String) -> Bool {}
func useSelector(_ sel: Selector) -> Bool {}

func test1() {
  let _ = useInt(##^POUND_EXPR_1^#)
  let _ = useString(##^POUND_EXPR_2^#)
  let _ = useSelector(##^POUND_EXPR_3^#)
}

// POUND_EXPR_INTCONTEXT: Begin completions, 10 items
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: function[#ExpressibleByStringLiteral#]; name=function
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: warning({#(message): String#})[#Void#]; name=warning(:)
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: error({#(message): String#})[#Void#]; name=error(:)
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: fileID[#ExpressibleByStringLiteral#]; name=fileID
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: file[#ExpressibleByStringLiteral#]; name=file
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: dsohandle[#UnsafeRawPointer#]; name=dsohandle
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: column[#ExpressibleByIntegerLiteral#]; name=column
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: line[#ExpressibleByIntegerLiteral#]; name=line
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: externalMacro({#module: String#}, {#type: String#})[#T#]; name=externalMacro(module:type:)
// POUND_EXPR_INTCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: filePath[#ExpressibleByStringLiteral#]; name=filePath
// POUND_EXPR_INTCONTEXT: End completions

// POUND_EXPR_STRINGCONTEXT: Begin completions, 11 items
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: function[#ExpressibleByStringLiteral#]; name=function
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: warning({#(message): String#})[#Void#]; name=warning(:)
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: error({#(message): String#})[#Void#]; name=error(:)
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: fileID[#ExpressibleByStringLiteral#]; name=fileID
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: file[#ExpressibleByStringLiteral#]; name=file
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: dsohandle[#UnsafeRawPointer#]; name=dsohandle
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: column[#ExpressibleByIntegerLiteral#]; name=column
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: line[#ExpressibleByIntegerLiteral#]; name=line
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: filePath[#ExpressibleByStringLiteral#]; name=filePath
// POUND_EXPR_STRINGCONTEXT-DAG: Keyword/None/TypeRelation[Convertible]: keyPath({#@objc property sequence#})[#String#];
// POUND_EXPR_STRINGCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: externalMacro({#module: String#}, {#type: String#})[#T#]; name=externalMacro(module:type:)
// POUND_EXPR_STRINGCONTEXT: End completions

// POUND_EXPR_SELECTORCONTEXT: Begin completions, 11 items
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: function[#ExpressibleByStringLiteral#]; name=function
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: warning({#(message): String#})[#Void#]; name=warning(:)
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: error({#(message): String#})[#Void#]; name=error(:)
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: fileID[#ExpressibleByStringLiteral#]; name=fileID
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: file[#ExpressibleByStringLiteral#]; name=file
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: dsohandle[#UnsafeRawPointer#]; name=dsohandle
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: column[#ExpressibleByIntegerLiteral#]; name=column
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: line[#ExpressibleByIntegerLiteral#]; name=line
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: filePath[#ExpressibleByStringLiteral#]; name=filePath
// POUND_EXPR_SELECTORCONTEXT-DAG: Keyword/None/TypeRelation[Convertible]: selector({#@objc method#})[#Selector#];
// POUND_EXPR_SELECTORCONTEXT-DAG: Decl[Macro]/OtherModule[Swift]/IsSystem: externalMacro({#module: String#}, {#type: String#})[#T#]; name=externalMacro(module:type:)
// POUND_EXPR_SELECTORCONTEXT: End completions
