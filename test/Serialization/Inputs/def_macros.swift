@freestanding(expression) public macro publicStringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

@freestanding(expression) macro internalStringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroDefinition", type: "StringifyMacro")

@attached(accessor) public macro myWrapper() = #externalMacro(module: "MacroDefinition", type: "MyWrapperMacro")

@attached(memberAttribute) public macro wrapAllProperties() = #externalMacro(module: "MacroDefinition", type: "WrapAllProperties")

// Make sure that macro custom attributes are not serialized.
@wrapAllProperties
public struct S {
  public var value: Int
}
