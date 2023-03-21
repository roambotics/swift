@freestanding(expression) public macro publicStringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

@freestanding(expression) macro internalStringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

@attached(accessor) public macro myWrapper() = #externalMacro(module: "MacroDefinition", type: "MyWrapperMacro")

@attached(memberAttribute) public macro wrapAllProperties() = #externalMacro(module: "MacroDefinition", type: "WrapAllProperties")

// Make sure that macro custom attributes are not serialized.
@wrapAllProperties
public struct S {
  public var value: Int
}

public struct Base {
  public static func member() -> Base { .init() }
}

@attached(memberAttribute) public macro wrapAllProperties(
  _ : Base
) = #externalMacro(module: "MacroDefinition", type: "WrapAllProperties")

@wrapAllProperties(.member())
public struct TestMacroArgTypechecking {
  public var value: Int
}

@resultBuilder
public struct Builder {
  public static func buildBlock(_: Int...) -> Void {}
}
@freestanding(expression)
public macro macroWithBuilderArgs(@Builder _: () -> Void) = #externalMacro(module: "A", type: "B")
