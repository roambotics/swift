// REQUIRES: asserts
// REQUIRES: swift_in_compiler
// REQUIRES: OS=macosx || OS=linux-gnu
// RUN: %batch-code-completion -enable-experimental-feature Embedded

func test() {
  #^GLOBAL^#
// GLOBAL: Literal[Integer]/None:              0[#Int#];
// GLOBAL: Literal[Boolean]/None:              true[#Bool#];
// GLOBAL: Literal[Boolean]/None:              false[#Bool#];
// GLOBAL: Literal[Nil]/None:                  nil;
// GLOBAL: Literal[String]/None:               "{#(abc)#}"[#String#];
// GLOBAL: Literal[Array]/None:                [{#(values)#}][#Array#];
// GLOBAL: Literal[Dictionary]/None:           [{#(key)#}: {#(value)#}][#Dictionary#];
}
