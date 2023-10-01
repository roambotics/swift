import CASTBridging
import CBasicBridging
import SwiftSyntax

extension BridgedSourceLoc: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self.init(raw: nil)
  }
}

extension BridgedIdentifier: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self.init(raw: nil)
  }
}

extension BridgedSourceLoc {
  /// Form a source location at the given absolute position in `buffer`.
  init(
    at position: AbsolutePosition,
    in buffer: UnsafeBufferPointer<UInt8>
  ) {
    precondition(position.utf8Offset >= 0 && position.utf8Offset <= buffer.count)
    self = SourceLoc_advanced(BridgedSourceLoc(raw: buffer.baseAddress!), SwiftInt(position.utf8Offset))
  }
}

extension BridgedSourceRange {
  @inline(__always)
  init(startToken: TokenSyntax, endToken: TokenSyntax, in astgen: ASTGenVisitor) {
    self.init(startLoc: startToken.bridgedSourceLoc(in: astgen), endLoc: endToken.bridgedSourceLoc(in: astgen))
  }
}

extension String {
  mutating func withBridgedString<R>(_ body: (BridgedString) throws -> R) rethrows -> R {
    try withUTF8 { buffer in
      try body(BridgedString(data: buffer.baseAddress, length: SwiftInt(buffer.count)))
    }
  }
}

extension SyntaxProtocol {
  /// Obtains the bridged start location of the node excluding leading trivia in the source buffer provided by `astgen`
  ///
  /// - Parameter astgen: The visitor providing the source buffer.
  @inline(__always)
  func bridgedSourceLoc(in astgen: ASTGenVisitor) -> BridgedSourceLoc { 
    return BridgedSourceLoc(at: self.positionAfterSkippingLeadingTrivia, in: astgen.base)
  }
}

extension Optional where Wrapped: SyntaxProtocol { 
  /// Obtains the bridged start location of the node excluding leading trivia in the source buffer provided by `astgen`.
  ///
  /// - Parameter astgen: The visitor providing the source buffer.
  @inline(__always)
  func bridgedSourceLoc(in astgen: ASTGenVisitor) -> BridgedSourceLoc { 
    guard let self else { 
      return nil
    }
    
    return self.bridgedSourceLoc(in: astgen)
  }
}

extension TokenSyntax {
  /// Obtains a bridged, `ASTContext`-owned copy of this token's text.
  ///
  /// - Parameter astgen: The visitor providing the `ASTContext`.
  @inline(__always)
  func bridgedIdentifier(in astgen: ASTGenVisitor) -> BridgedIdentifier {
    var text = self.text
    return text.withBridgedString { bridged in
      ASTContext_getIdentifier(astgen.ctx, bridged)
    }
  }

  /// Obtains a bridged, `ASTContext`-owned copy of this token's text, and its bridged start location in the
  /// source buffer provided by `astgen`.
  ///
  /// - Parameter astgen: The visitor providing the `ASTContext` and source buffer.
  @inline(__always)
  func bridgedIdentifierAndSourceLoc(in astgen: ASTGenVisitor) -> (BridgedIdentifier, BridgedSourceLoc) {
    return (self.bridgedIdentifier(in: astgen), self.bridgedSourceLoc(in: astgen))
  }

  /// Obtains a bridged, `ASTContext`-owned copy of this token's text, and its bridged start location in the
  /// source buffer provided by `astgen`.
  ///
  /// - Parameter astgen: The visitor providing the `ASTContext` and source buffer.
  @inline(__always)
  func bridgedIdentifierAndSourceLoc(in astgen: ASTGenVisitor) -> BridgedIdentifierAndSourceLoc {
    let (name, nameLoc) = self.bridgedIdentifierAndSourceLoc(in: astgen)
    return .init(name: name, nameLoc: nameLoc)
  }
}

extension Optional<TokenSyntax> {
  /// Obtains a bridged, `ASTContext`-owned copy of this token's text.
  ///
  /// - Parameter astgen: The visitor providing the `ASTContext`.
  @inline(__always)
  func bridgedIdentifier(in astgen: ASTGenVisitor) -> BridgedIdentifier {
    guard let self else {
      return nil
    }

    return self.bridgedIdentifier(in: astgen)
  }

  /// Obtains a bridged, `ASTContext`-owned copy of this token's text, and its bridged start location in the
  /// source buffer provided by `astgen` excluding leading trivia.
  ///
  /// - Parameter astgen: The visitor providing the `ASTContext` and source buffer.
  @inline(__always)
  func bridgedIdentifierAndSourceLoc(in astgen: ASTGenVisitor) -> (BridgedIdentifier, BridgedSourceLoc) {
    guard let self else {
      return (nil, nil)
    }

    return self.bridgedIdentifierAndSourceLoc(in: astgen)
  }
}
