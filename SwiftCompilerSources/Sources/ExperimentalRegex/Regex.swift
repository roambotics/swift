import ExperimentalRegexBridging

public func registerRegexParser() {
  Parser_registerRegexLiteralParsingFn(libswiftParseRegexLiteral)
  Parser_registerRegexLiteralLexingFn(libswiftLexRegexLiteral)
}
