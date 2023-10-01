//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import CASTBridging
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftCompilerPluginMessageHandling

// Needed to use SyntaxTransformVisitor's visit method.
@_spi(SyntaxTransformVisitor)
import SwiftSyntax

extension SyntaxProtocol {
  func token(at position: AbsolutePosition) -> TokenSyntax? {
    // If the position isn't within this node at all, return early.
    guard position >= self.position && position < self.endPosition else {
      return nil
    }

    // If we are a token syntax, that's it!
    if let token = Syntax(self).as(TokenSyntax.self) {
      return token
    }

    // Otherwise, it must be one of our children.
    for child in children(viewMode: .sourceAccurate) {
      if let token = child.token(at: position) {
        return token
      }
    }
    fatalError("Children of syntax node do not cover all positions in it")
  }
}

/// Describes a macro that has been "exported" to the C++ part of the
/// compiler, with enough information to interface with the C++ layer.
struct ExportedMacro {
  var macro: Macro.Type
}

struct ExportedExecutableMacro {
  var moduleName: String
  var typeName: String
  var plugin: CompilerPlugin
}

enum MacroPluginKind: UInt8 {
  case InProcess = 0
  case Executable = 1
}

extension MacroRole {
  init(rawMacroRole: UInt8) {
    switch rawMacroRole {
    case 0: self = .expression
    case 1: self = .declaration
    case 2: self = .accessor
    case 3: self = .memberAttribute
    case 4: self = .member
    case 5: self = .peer
    case 6: self = .conformance
    case 7: self = .codeItem
    case 8: self = .`extension`

    default: fatalError("unknown macro role")
    }
  }
}

extension String {
  public init(bufferStart: UnsafePointer<UInt8>?, count: Int) {
    let buffer = UnsafeBufferPointer(start: bufferStart, count: count)
    self.init(decoding: buffer, as: UTF8.self)
  }
}

/// Resolve a reference to type metadata into a macro, if posible.
///
/// Returns an unmanaged pointer to an ExportedMacro instance that describes
/// the specified macro. If there is no macro with the given name, produces
/// nil.
@_cdecl("swift_ASTGen_resolveMacroType")
public func resolveMacroType(
  macroTypePtr: UnsafePointer<UInt8>
) -> UnsafeRawPointer? {
  let macroType = unsafeBitCast(macroTypePtr, to: Any.Type.self)

  guard let macro = macroType as? Macro.Type else {
    return nil
  }

  // Allocate and initialize the exported macro.
  let exportedPtr = UnsafeMutablePointer<ExportedMacro>.allocate(capacity: 1)
  exportedPtr.initialize(to: .init(macro: macro))
  return UnsafeRawPointer(exportedPtr)
}

/// Destroys the given macro.
@_cdecl("swift_ASTGen_destroyMacro")
public func destroyMacro(
  macroPtr: UnsafeMutablePointer<UInt8>
) {
  macroPtr.withMemoryRebound(to: ExportedMacro.self, capacity: 1) { macro in
    macro.deinitialize(count: 1)
    macro.deallocate()
  }
}

@_cdecl("swift_ASTGen_resolveExecutableMacro")
public func resolveExecutableMacro(
  moduleName: UnsafePointer<UInt8>,
  moduleNameLength: Int,
  typeName: UnsafePointer<UInt8>,
  typeNameLength: Int,
  pluginOpaqueHandle: UnsafeMutableRawPointer
) -> UnsafeRawPointer {
  // NOTE: This doesn't actually resolve anything.
  // Executable plugins is "trusted" to have the macro implementation. If not,
  // the actual expansion fails.
  let exportedPtr = UnsafeMutablePointer<ExportedExecutableMacro>.allocate(capacity: 1)
  exportedPtr.initialize(to: .init(
    moduleName: String(bufferStart: moduleName, count: moduleNameLength),
    typeName: String(bufferStart: typeName, count: typeNameLength),
    plugin: CompilerPlugin(opaqueHandle: pluginOpaqueHandle)))
  return UnsafeRawPointer(exportedPtr)
}

@_cdecl("swift_ASTGen_destroyExecutableMacro")
public func destroyExecutableMacro(
  macroPtr: UnsafeMutableRawPointer
) {
  let macroPtr = macroPtr.assumingMemoryBound(to: ExportedExecutableMacro.self)
  macroPtr.deinitialize(count: 1)
  macroPtr.deallocate()
}

/// Allocate a copy of the given string as a UTF-8 string.
func allocateUTF8String(
  _ string: String,
  nullTerminated: Bool = false
) -> (UnsafePointer<UInt8>, Int) {
  var string = string
  return string.withUTF8 { utf8 in
    let capacity = utf8.count + (nullTerminated ? 1 : 0)
    let ptr = UnsafeMutablePointer<UInt8>.allocate(
      capacity: capacity
    )
    if let baseAddress = utf8.baseAddress {
      ptr.initialize(from: baseAddress, count: utf8.count)
    }

    if nullTerminated {
      ptr[utf8.count] = 0
    }

    return (UnsafePointer<UInt8>(ptr), utf8.count)
  }
}

@_cdecl("swift_ASTGen_freeString")
public func freeString(pointer: UnsafePointer<UInt8>?) {
  pointer?.deallocate()
}

/// Diagnostics produced here.
enum ASTGenMacroDiagnostic: DiagnosticMessage, FixItMessage {
  case thrownError(Error)
  case oldStyleExternalMacro
  case useExternalMacro
  case unknownBuiltin(String)
  case notStringLiteralArgument(String)

  var message: String {
    switch self {
    case .thrownError(let error):
      if let err = error as? PluginError {
        return err.description
      } else {
        return String(describing: error)
      }

    case .oldStyleExternalMacro:
      return "external macro definitions are now written using #externalMacro"

    case .useExternalMacro:
      return "use '#externalMacro'"

    case .unknownBuiltin(let type):
      return "ignoring definition of unknown builtin macro \(type)"

    case .notStringLiteralArgument(let kind):
      return "argument to `#externalMacro` must be a string literal naming the external macro's \(kind)"
    }
  }

  var severity: DiagnosticSeverity {
    switch self {
    case .thrownError, .notStringLiteralArgument:
      return .error

    case .oldStyleExternalMacro, .unknownBuiltin:
      return .warning

    case .useExternalMacro:
      return .note
    }
  }

  var diagnosticID: MessageID {
    .init(domain: "Swift", id: "\(self)")
  }

  var fixItID: MessageID { diagnosticID }
}

/// Treat the given expression as a string literal, which should contain a
/// single identifier.
fileprivate func identifierFromStringLiteral(_ node: ExprSyntax) -> String? {
  guard let stringLiteral = node.as(StringLiteralExprSyntax.self),
        stringLiteral.segments.count == 1,
        let segment = stringLiteral.segments.first,
        case .stringSegment(let stringSegment) = segment else {
    return nil
  }

  return stringSegment.content.text
}

/// Check a macro definition, producing a description of that macro definition
/// for use in macro expansion.
///
/// When the resulting macro requires expansion, the result will come in
/// two parts: 
///
/// - Returns: -1 on failure, BridgedMacroDefinitionKind on success. When the
/// successful result is "expanded macro", `replacementsPtr` will point to a
/// number of "replacements" to perform when expanding that macro. Each
/// replacement is a textual replacement of use of a macro parameter with the
/// source text of the corresponding argument, and is represented as a triple
/// (start offset, end offset, parameter index): the [start offset, end offset)
/// range in the macro expansion expression should be replaced with the
/// argument matching the corresponding parameter.
@_cdecl("swift_ASTGen_checkMacroDefinition")
func checkMacroDefinition(
    diagEnginePtr: UnsafeMutablePointer<UInt8>,
    sourceFilePtr: UnsafeRawPointer,
    macroLocationPtr: UnsafePointer<UInt8>,
    externalMacroPointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
    externalMacroLength: UnsafeMutablePointer<Int>,
    replacementsPtr: UnsafeMutablePointer<UnsafeMutablePointer<Int>?>,
    numReplacementsPtr: UnsafeMutablePointer<Int>
) -> Int {
  // Clear out the "out" parameters.
  externalMacroPointer.pointee = nil
  externalMacroLength.pointee = 0
  replacementsPtr.pointee = nil
  numReplacementsPtr.pointee = 0

  let sourceFilePtr = sourceFilePtr.bindMemory(to: ExportedSourceFile.self, capacity: 1)

  // Find the macro declaration.
  guard let macroDecl = findSyntaxNodeInSourceFile(
    sourceFilePtr: sourceFilePtr,
    sourceLocationPtr: macroLocationPtr,
    type: MacroDeclSyntax.self
  ) else {
    // FIXME: Produce an error
    return -1
  }

  // Check the definition
  do {
    let definition = try macroDecl.checkDefinition()
    switch definition {
    case let .deprecatedExternal(node: node, module: module, type: type):
      // Check for known builtins.
      if module == "Builtin" {
        switch type {
        case "ExternalMacro":
          return Int(BridgedMacroDefinitionKind.builtinExternalMacro.rawValue)

        default:
          // Warn about the unknown builtin.
          let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
          srcMgr.insert(sourceFilePtr)
          srcMgr.diagnose(
            diagnostic: .init(
              node: node,
              message: ASTGenMacroDiagnostic.unknownBuiltin(type)
            )
          )

          return -1
        }
      }

      // Form the "ModuleName.TypeName" result string.
      (externalMacroPointer.pointee, externalMacroLength.pointee) =
        allocateUTF8String("\(module).\(type)", nullTerminated: true)

      // Translate this into a use of #externalMacro.
      let expansionSourceSyntax: ExprSyntax =
        "#externalMacro(module: \(literal: module), type: \(literal: type))"

      // Warn about the use of old-style external macro syntax here.
      let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
      srcMgr.insert(sourceFilePtr)
      srcMgr.diagnose(
        diagnostic: .init(
          node: node,
          message: ASTGenMacroDiagnostic.oldStyleExternalMacro,
          fixIts: [
            FixIt(
              message: ASTGenMacroDiagnostic.useExternalMacro,
              changes: [
                FixIt.Change.replace(
                  oldNode: node,
                  newNode: Syntax(expansionSourceSyntax)
                )
              ]
            )
          ]
        )
      )
      return Int(BridgedMacroDefinitionKind.externalMacro.rawValue)

    case let .expansion(expansionSyntax, replacements: _)
        where expansionSyntax.macroName.text == "externalMacro":
      // Extract the identifier from the "module" argument.
      guard let firstArg = expansionSyntax.arguments.first,
            let firstArgLabel = firstArg.label?.text,
            firstArgLabel == "module",
            let module = identifierFromStringLiteral(firstArg.expression) else {
        let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
        srcMgr.insert(sourceFilePtr)
        srcMgr.diagnose(
          diagnostic: .init(
            node: Syntax(expansionSyntax),
            message: ASTGenMacroDiagnostic.notStringLiteralArgument("module")
          )
        )
        return -1
      }

      // Extract the identifier from the "type" argument.
      guard let secondArg = expansionSyntax.arguments.dropFirst().first,
            let secondArgLabel = secondArg.label?.text,
            secondArgLabel == "type",
            let type = identifierFromStringLiteral(secondArg.expression) else {
        let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
        srcMgr.insert(sourceFilePtr)
        srcMgr.diagnose(
          diagnostic: .init(
            node: Syntax(expansionSyntax),
            message: ASTGenMacroDiagnostic.notStringLiteralArgument("type")
          )
        )
        return -1
      }

      // Form the "ModuleName.TypeName" result string.
      (externalMacroPointer.pointee, externalMacroLength.pointee) =
        allocateUTF8String("\(module).\(type)", nullTerminated: true)
      return Int(BridgedMacroDefinitionKind.externalMacro.rawValue)

    case let .expansion(expansionSyntax, replacements: replacements):
      // Provide the expansion syntax.
      (externalMacroPointer.pointee, externalMacroLength.pointee) =
        allocateUTF8String(expansionSyntax.trimmedDescription,
                           nullTerminated: true)


      // If there are no replacements, we're done.
      if replacements.isEmpty {
        return Int(BridgedMacroDefinitionKind.expandedMacro.rawValue)
      }

      // The replacements are triples: (startOffset, endOffset, parameter index).
      let replacementBuffer = UnsafeMutableBufferPointer<Int>.allocate(capacity: 3 * replacements.count)
      for (index, replacement) in replacements.enumerated() {
        let expansionStart = expansionSyntax.positionAfterSkippingLeadingTrivia.utf8Offset

        replacementBuffer[index * 3] = replacement.reference.positionAfterSkippingLeadingTrivia.utf8Offset - expansionStart
        replacementBuffer[index * 3 + 1] = replacement.reference.endPositionBeforeTrailingTrivia.utf8Offset - expansionStart
        replacementBuffer[index * 3 + 2] = replacement.parameterIndex
      }

      replacementsPtr.pointee = replacementBuffer.baseAddress
      numReplacementsPtr.pointee = replacements.count
      return Int(BridgedMacroDefinitionKind.expandedMacro.rawValue)
    }
  } catch let errDiags as DiagnosticsError {
    let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
    srcMgr.insert(sourceFilePtr)
    for diag in errDiags.diagnostics {
      srcMgr.diagnose(diagnostic: diag)
    }
    return -1
  } catch let error {
    let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
    srcMgr.insert(sourceFilePtr)
    srcMgr.diagnose(
      diagnostic: .init(
        node: Syntax(macroDecl),
        message: ASTGenMacroDiagnostic.thrownError(error)
      )
    )
    return -1
  }
}

@_cdecl("swift_ASTGen_freeExpansionReplacements")
public func freeExpansionReplacements(
  pointer: UnsafeMutablePointer<Int>?,
  numReplacements: Int
) {
  UnsafeMutableBufferPointer(start: pointer, count: numReplacements).deallocate()
}

// Make an expansion result for '@_cdecl' function caller.
func makeExpansionOutputResult(
  expandedSource: String?,
  outputPointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  outputLength: UnsafeMutablePointer<Int>
) -> Int {
  guard var expandedSource = expandedSource else {
    return -1
  }

  // Form the result buffer for our caller.
  expandedSource.withUTF8 { utf8 in
    let evaluatedResultPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: utf8.count + 1)
    if let baseAddress = utf8.baseAddress {
      evaluatedResultPtr.initialize(from: baseAddress, count: utf8.count)
    }
    evaluatedResultPtr[utf8.count] = 0

    outputPointer.pointee = UnsafePointer(evaluatedResultPtr)
    outputLength.pointee = utf8.count
  }
  return 0
}

@_cdecl("swift_ASTGen_expandFreestandingMacro")
@usableFromInline
func expandFreestandingMacro(
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  macroPtr: UnsafeRawPointer,
  macroKind: UInt8,
  discriminatorText: UnsafePointer<UInt8>,
  discriminatorTextLength: Int,
  rawMacroRole: UInt8,
  sourceFilePtr: UnsafeRawPointer,
  sourceLocationPtr: UnsafePointer<UInt8>?,
  expandedSourcePointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  expandedSourceLength: UnsafeMutablePointer<Int>
) -> Int {
  // We didn't expand anything so far.
  expandedSourcePointer.pointee = nil
  expandedSourceLength.pointee = 0

  guard let sourceLocationPtr = sourceLocationPtr else {
    print("NULL source location")
    return -1
  }

  let sourceFilePtr = sourceFilePtr.bindMemory(to: ExportedSourceFile.self, capacity: 1)

  guard let macroSyntax = findSyntaxNodeInSourceFile(
    sourceFilePtr: sourceFilePtr, sourceLocationPtr: sourceLocationPtr, type: Syntax.self) else {
    return 1
  }
  guard let expansion = macroSyntax.asProtocol(
    FreestandingMacroExpansionSyntax.self
  ) else {
    print("not on a macro expansion node: \(macroSyntax.debugDescription)")
    return 1
  }

  let discriminatorBuffer = UnsafeBufferPointer(
    start: discriminatorText, count: discriminatorTextLength
  )
  let discriminator = String(decoding: discriminatorBuffer, as: UTF8.self)

  let macroRole = MacroRole(rawMacroRole: rawMacroRole)
  let expandedSource: String?
  switch MacroPluginKind(rawValue: macroKind)! {
  case .InProcess:
    expandedSource = expandFreestandingMacroInProcess(
      macroPtr: macroPtr,
      macroRole: macroRole,
      diagEnginePtr: diagEnginePtr,
      expansionSyntax: expansion,
      sourceFilePtr: sourceFilePtr,
      discriminator: discriminator)
  case .Executable:
    expandedSource = expandFreestandingMacroIPC(
      macroPtr: macroPtr,
      macroRole: macroRole,
      diagEnginePtr: diagEnginePtr,
      expansionSyntax: expansion,
      sourceFilePtr: sourceFilePtr,
      discriminator: discriminator)
  }

  return makeExpansionOutputResult(
    expandedSource: expandedSource,
    outputPointer: expandedSourcePointer,
    outputLength: expandedSourceLength
  )
}

func expandFreestandingMacroIPC(
  macroPtr: UnsafeRawPointer,
  macroRole: MacroRole,
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  expansionSyntax: FreestandingMacroExpansionSyntax,
  sourceFilePtr: UnsafePointer<ExportedSourceFile>,
  discriminator: String
) -> String? {

  let macroName: String
  if let exprSyntax = expansionSyntax.as(MacroExpansionExprSyntax.self) {
    macroName = exprSyntax.macroName.text
  } else if let declSyntax = expansionSyntax.as(MacroExpansionDeclSyntax.self) {
    macroName = declSyntax.macroName.text
  } else {
    fatalError("unknown syntax")
  }

  let macro = macroPtr.assumingMemoryBound(to: ExportedExecutableMacro.self).pointee

  // Map the macro role.
  let pluginMacroRole: PluginMessage.MacroRole
  switch macroRole {
  case .accessor, .member, .memberAttribute, .peer, .conformance, .extension:
    preconditionFailure("unhandled macro role for freestanding macro")

  case .expression: pluginMacroRole = .expression
  case .declaration: pluginMacroRole = .declaration
  case .codeItem: pluginMacroRole = .codeItem
  }

  // Send the message.
  let message = HostToPluginMessage.expandFreestandingMacro(
    macro: .init(moduleName: macro.moduleName, typeName: macro.typeName, name: macroName),
    macroRole: pluginMacroRole,
    discriminator: discriminator,
    syntax: PluginMessage.Syntax(syntax: Syntax(expansionSyntax), in: sourceFilePtr)!)
  do {
    let result = try macro.plugin.sendMessageAndWait(message)
    let expandedSource: String?
    let diagnostics: [PluginMessage.Diagnostic]
    switch result {
    case
        .expandMacroResult(let _expandedSource, let _diagnostics),
        .expandFreestandingMacroResult(let _expandedSource, let _diagnostics):
      expandedSource = _expandedSource
      diagnostics = _diagnostics
    default:
      throw PluginError.invalidReponseKind
    }

    // Process the result.
    if !diagnostics.isEmpty {
      let diagEngine = PluginDiagnosticsEngine(cxxDiagnosticEngine: diagEnginePtr)
      diagEngine.add(exportedSourceFile: sourceFilePtr)
      diagEngine.emit(diagnostics, messageSuffix: " (from macro '\(macroName)')")
    }
    return expandedSource

  } catch let error {
    let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
    srcMgr.insert(sourceFilePtr)
    srcMgr.diagnose(
      diagnostic: .init(
        node: Syntax(expansionSyntax),
        // FIXME: This is probably a plugin communication error.
        // The error might not be relevant as the diagnostic message.
        message: ASTGenMacroDiagnostic.thrownError(error)
      ),
      messageSuffix: " (from macro '\(macroName)')"
    )
    return nil
  }
}

func expandFreestandingMacroInProcess(
  macroPtr: UnsafeRawPointer,
  macroRole: MacroRole,
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  expansionSyntax: FreestandingMacroExpansionSyntax,
  sourceFilePtr: UnsafePointer<ExportedSourceFile>,
  discriminator: String
) -> String? {
  // Get the macro.
  let macroPtr = macroPtr.bindMemory(to: ExportedMacro.self, capacity: 1)
  let macro = macroPtr.pointee.macro

  // Create a source manager. This should probably persist and be given to us.
  let sourceManager = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
  sourceManager.insert(sourceFilePtr)

  let context = sourceManager.createMacroExpansionContext(
    discriminator: discriminator
  )

  let macroName = expansionSyntax.macro.text

  // Make sure we emit all of the diagnostics from the context.
  defer {
    // Emit diagnostics accumulated in the context.
    for diag in context.diagnostics {
      sourceManager.diagnose(
        diagnostic: diag,
        messageSuffix: " (from macro '\(macroName)')"
      )
    }

    context.diagnostics = []
  }

  let node = sourceManager.detach(
    expansionSyntax,
    foldingWith: OperatorTable.standardOperators
  )

  return SwiftSyntaxMacroExpansion.expandFreestandingMacro(
    definition: macro,
    macroRole: macroRole,
    node: node,
    in: context
  )
}

/// Retrieve a syntax node in the given source file, with the given type.
func findSyntaxNodeInSourceFile<Node: SyntaxProtocol>(
  sourceFilePtr: UnsafeRawPointer,
  sourceLocationPtr: UnsafePointer<UInt8>?,
  type: Node.Type,
  wantOutermost: Bool = false
) -> Node? {
  guard let sourceLocationPtr = sourceLocationPtr else {
    return nil
  }

  let sourceFilePtr = sourceFilePtr.bindMemory(
    to: ExportedSourceFile.self, capacity: 1
  )

  // Find the offset.
  let buffer = sourceFilePtr.pointee.buffer
  let offset = sourceLocationPtr - buffer.baseAddress!
  if offset < 0 || offset >= buffer.count {
    print("source location isn't inside this buffer")
    return nil
  }

  // Find the token at that offset.
  let sf = sourceFilePtr.pointee.syntax
  guard let token = sf.token(at: AbsolutePosition(utf8Offset: offset)) else {
    print("couldn't find token at offset \(offset)")
    return nil
  }

  var currentSyntax = Syntax(token)
  var resultSyntax: Node? = nil
  while let parentSyntax = currentSyntax.parent {
    if let typedParent = parentSyntax.as(type) {
      resultSyntax = typedParent
      break
    }

    currentSyntax = parentSyntax
  }

  // If we didn't find anything, complain and fail.
  guard var resultSyntax else {
    print("unable to find node: \(token.debugDescription)")
    return nil
  }

  // If we want the outermost node, keep looking.
  // FIXME: This is VERY SPECIFIC to handling of types. We must be able to
  // do better.
  if wantOutermost {
    while let parentSyntax = resultSyntax.parent {
      // Look through type compositions.
      if let compositionElement = parentSyntax.as(CompositionTypeElementSyntax.self),
         let compositionList = compositionElement.parent?.as(CompositionTypeElementListSyntax.self),
         let typedParent = compositionList.parent?.as(type) {
        resultSyntax = typedParent
        continue
      }

      guard let typedParent = parentSyntax.as(type),
            typedParent.position == resultSyntax.position else {
        break
      }

      resultSyntax = typedParent
    }
  }

  return resultSyntax
}

@_cdecl("swift_ASTGen_expandAttachedMacro")
@usableFromInline
func expandAttachedMacro(
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  macroPtr: UnsafeRawPointer,
  macroKind: UInt8,
  discriminatorText: UnsafePointer<UInt8>,
  discriminatorTextLength: Int,
  qualifiedTypeText: UnsafePointer<UInt8>,
  qualifiedTypeLength: Int,
  conformanceListText: UnsafePointer<UInt8>,
  conformanceListLength: Int,
  rawMacroRole: UInt8,
  customAttrSourceFilePtr: UnsafeRawPointer,
  customAttrSourceLocPointer: UnsafePointer<UInt8>?,
  declarationSourceFilePtr: UnsafeRawPointer,
  attachedTo declarationSourceLocPointer: UnsafePointer<UInt8>?,
  parentDeclSourceFilePtr: UnsafeRawPointer?,
  parentDeclSourceLocPointer: UnsafePointer<UInt8>?,
  expandedSourcePointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>,
  expandedSourceLength: UnsafeMutablePointer<Int>
) -> Int {
  // We didn't expand anything so far.
  expandedSourcePointer.pointee = nil
  expandedSourceLength.pointee = 0

  // Dig out the custom attribute for the attached macro declarations.
  guard let customAttrNode = findSyntaxNodeInSourceFile(
    sourceFilePtr: customAttrSourceFilePtr,
    sourceLocationPtr: customAttrSourceLocPointer,
    type: AttributeSyntax.self
  ) else {
    return 1
  }

  // Dig out the node for the declaration to which the custom attribute is
  // attached.
  guard let declarationNode = findSyntaxNodeInSourceFile(
    sourceFilePtr: declarationSourceFilePtr,
    sourceLocationPtr: declarationSourceLocPointer,
    type: DeclSyntax.self
  ) else {
    return 1
  }

  var parentDeclNode: DeclSyntax?
  if let parentDeclSourceFilePtr = parentDeclSourceFilePtr {
    parentDeclNode = findSyntaxNodeInSourceFile(
      sourceFilePtr: parentDeclSourceFilePtr,
      sourceLocationPtr: parentDeclSourceLocPointer,
      type: DeclSyntax.self
    )
  }

  let customAttrSourceFilePtr = customAttrSourceFilePtr.bindMemory(to: ExportedSourceFile.self, capacity: 1)
  let declarationSourceFilePtr = declarationSourceFilePtr.bindMemory(to: ExportedSourceFile.self, capacity: 1)
  let parentDeclSourceFilePtr = parentDeclSourceFilePtr?.bindMemory(to: ExportedSourceFile.self, capacity: 1)

  let discriminatorBuffer = UnsafeBufferPointer(
    start: discriminatorText, count: discriminatorTextLength
  )
  let discriminator = String(decoding: discriminatorBuffer, as: UTF8.self)

  let qualifiedTypeBuffer = UnsafeBufferPointer(
    start: qualifiedTypeText, count: qualifiedTypeLength
  )
  let qualifiedType = String(decoding: qualifiedTypeBuffer, as: UTF8.self)

  let conformanceListBuffer = UnsafeBufferPointer(
    start: conformanceListText, count: conformanceListLength
  )
  let conformanceList = String(decoding: conformanceListBuffer, as: UTF8.self)


  let expandedSource: String?
  switch MacroPluginKind(rawValue: macroKind)! {
  case .Executable:
    expandedSource = expandAttachedMacroIPC(
      diagEnginePtr: diagEnginePtr,
      macroPtr: macroPtr,
      rawMacroRole: rawMacroRole,
      discriminator: discriminator,
      qualifiedType: qualifiedType,
      conformanceList: conformanceList,
      customAttrSourceFilePtr: customAttrSourceFilePtr,
      customAttrNode: customAttrNode,
      declarationSourceFilePtr: declarationSourceFilePtr,
      attachedTo: declarationNode,
      parentDeclSourceFilePtr: parentDeclSourceFilePtr,
      parentDeclNode: parentDeclNode)
  case .InProcess:
    expandedSource = expandAttachedMacroInProcess(
      diagEnginePtr: diagEnginePtr,
      macroPtr: macroPtr,
      rawMacroRole: rawMacroRole,
      discriminator: discriminator,
      qualifiedType: qualifiedType,
      conformanceList: conformanceList,
      customAttrSourceFilePtr: customAttrSourceFilePtr,
      customAttrNode: customAttrNode,
      declarationSourceFilePtr: declarationSourceFilePtr,
      attachedTo: declarationNode,
      parentDeclSourceFilePtr: parentDeclSourceFilePtr,
      parentDeclNode: parentDeclNode)
  }

  return makeExpansionOutputResult(
    expandedSource: expandedSource,
    outputPointer: expandedSourcePointer,
    outputLength: expandedSourceLength
  )
}

func expandAttachedMacroIPC(
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  macroPtr: UnsafeRawPointer,
  rawMacroRole: UInt8,
  discriminator: String,
  qualifiedType: String,
  conformanceList: String,
  customAttrSourceFilePtr: UnsafePointer<ExportedSourceFile>,
  customAttrNode: AttributeSyntax,
  declarationSourceFilePtr: UnsafePointer<ExportedSourceFile>,
  attachedTo declarationNode: DeclSyntax,
  parentDeclSourceFilePtr: UnsafePointer<ExportedSourceFile>?,
  parentDeclNode: DeclSyntax?
) -> String? {
  let macroName: String = customAttrNode.attributeName.description
  let macro = macroPtr.assumingMemoryBound(to: ExportedExecutableMacro.self).pointee

  // Map the macro role.
  let macroRole: PluginMessage.MacroRole
  switch MacroRole(rawMacroRole: rawMacroRole) {
  case .accessor: macroRole = .accessor
  case .member: macroRole = .member
  case .memberAttribute: macroRole = .memberAttribute
  case .peer: macroRole = .peer
  case .conformance: macroRole = .conformance
  case .extension: macroRole = .`extension`
  case
      .expression,
      .declaration,
      .codeItem:
    preconditionFailure("unhandled macro role for attached macro")
  }

  // Prepare syntax nodes to transfer.
  let customAttributeSyntax = PluginMessage.Syntax(
    syntax: Syntax(customAttrNode), in: customAttrSourceFilePtr)!

  let declSyntax = PluginMessage.Syntax(
    syntax: Syntax(declarationNode), in: customAttrSourceFilePtr)!

  let parentDeclSyntax: PluginMessage.Syntax?
  if parentDeclNode != nil {
    parentDeclSyntax = .init(syntax: Syntax(parentDeclNode!), in: parentDeclSourceFilePtr!)!
  } else {
    parentDeclSyntax = nil
  }

  let extendedTypeSyntax: PluginMessage.Syntax?
  if (!qualifiedType.isEmpty) {
    let typeSyntax: TypeSyntax = "\(raw: qualifiedType)"
    extendedTypeSyntax = .init(syntax: Syntax(typeSyntax))!
  } else {
    extendedTypeSyntax = nil
  }

  let conformanceListSyntax: PluginMessage.Syntax?
  if (conformanceList.isEmpty) {
    conformanceListSyntax = nil
  } else {
    let placeholderDecl: DeclSyntax =
      """
      struct Placeholder: \(raw: conformanceList) {}
      """
    conformanceListSyntax = .init(syntax: Syntax(placeholderDecl))!
  }

  // Send the message.
  let message = HostToPluginMessage.expandAttachedMacro(
    macro: .init(moduleName: macro.moduleName, typeName: macro.typeName, name: macroName),
    macroRole: macroRole,
    discriminator: discriminator,
    attributeSyntax: customAttributeSyntax,
    declSyntax: declSyntax,
    parentDeclSyntax: parentDeclSyntax,
    extendedTypeSyntax: extendedTypeSyntax,
    conformanceListSyntax: conformanceListSyntax)
  do {
    let expandedSource: String?
    let diagnostics: [PluginMessage.Diagnostic]
    switch try macro.plugin.sendMessageAndWait(message) {
    case .expandMacroResult(let _expandedSource, let _diagnostics):
      expandedSource = _expandedSource
      diagnostics = _diagnostics

    // Handle legacy result message.
    case .expandAttachedMacroResult(let _expandedSources, let _diagnostics):
      if let _expandedSources = _expandedSources {
        expandedSource = SwiftSyntaxMacroExpansion.collapse(
          expansions: _expandedSources,
          for: MacroRole(rawMacroRole: rawMacroRole),
          attachedTo: declarationNode
        )
      } else {
        expandedSource = nil
      }
      diagnostics = _diagnostics
      break
    default:
      throw PluginError.invalidReponseKind
    }

    // Process the result.
    if !diagnostics.isEmpty {
      let diagEngine = PluginDiagnosticsEngine(cxxDiagnosticEngine: diagEnginePtr)
      diagEngine.add(exportedSourceFile: customAttrSourceFilePtr)
      diagEngine.add(exportedSourceFile: declarationSourceFilePtr)
      if let parentDeclSourceFilePtr = parentDeclSourceFilePtr {
        diagEngine.add(exportedSourceFile: parentDeclSourceFilePtr)
      }
      diagEngine.emit(diagnostics, messageSuffix: " (from macro '\(macroName)')")
    }
    return expandedSource

  } catch let error {
    let srcMgr = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
    srcMgr.insert(customAttrSourceFilePtr)
    srcMgr.insert(declarationSourceFilePtr)
    if let parentDeclSourceFilePtr = parentDeclSourceFilePtr {
      srcMgr.insert(parentDeclSourceFilePtr)
    }
    // FIXME: Need to decide where to diagnose the error:
    srcMgr.diagnose(
      diagnostic: .init(
        node: Syntax(declarationNode),
        // FIXME: This is probably a plugin communication error.
        // The error might not be relevant as the diagnostic message.
        message: ASTGenMacroDiagnostic.thrownError(error)
      ),
      messageSuffix: " (from macro '\(macroName)')"
    )
    return nil
  }
}

func expandAttachedMacroInProcess(
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  macroPtr: UnsafeRawPointer,
  rawMacroRole: UInt8,
  discriminator: String,
  qualifiedType: String,
  conformanceList: String,
  customAttrSourceFilePtr: UnsafePointer<ExportedSourceFile>,
  customAttrNode: AttributeSyntax,
  declarationSourceFilePtr: UnsafePointer<ExportedSourceFile>,
  attachedTo declarationNode: DeclSyntax,
  parentDeclSourceFilePtr: UnsafePointer<ExportedSourceFile>?,
  parentDeclNode: DeclSyntax?
) -> String? {
  // Get the macro.
  let macroPtr = macroPtr.bindMemory(to: ExportedMacro.self, capacity: 1)
  let macro = macroPtr.pointee.macro

  // Create a source manager covering the files we know about.
  let sourceManager = SourceManager(cxxDiagnosticEngine: diagEnginePtr)
  sourceManager.insert(customAttrSourceFilePtr)
  sourceManager.insert(declarationSourceFilePtr)
  if let parentDeclSourceFilePtr = parentDeclSourceFilePtr {
    sourceManager.insert(parentDeclSourceFilePtr)
  }

  // Create an expansion context
  let context = sourceManager.createMacroExpansionContext(
    discriminator: discriminator
  )

  let macroName = customAttrNode.attributeName.trimmedDescription

  // Emit all of the accumulated diagnostics before we exit.
  defer {
    // Emit diagnostics accumulated in the context.
    for diag in context.diagnostics {
      sourceManager.diagnose(
        diagnostic: diag,
        messageSuffix: " (from macro '\(macroName)')"
      )
    }

    context.diagnostics = []
  }

  let attributeNode = sourceManager.detach(
    customAttrNode,
    foldingWith: OperatorTable.standardOperators
  )
  let declarationNode = sourceManager.detach(declarationNode)
  let parentDeclNode = parentDeclNode.map { sourceManager.detach($0) }
  let extendedType: TypeSyntax = "\(raw: qualifiedType)"

  let conformanceListSyntax: InheritedTypeListSyntax?
  if (conformanceList.isEmpty) {
    conformanceListSyntax = nil
  } else {
    let placeholderDecl: DeclSyntax =
      """
      struct Placeholder: \(raw: conformanceList) {}
      """
    let placeholderStruct = placeholderDecl.cast(StructDeclSyntax.self)
    if let inheritanceClause = placeholderStruct.inheritanceClause {
      conformanceListSyntax = inheritanceClause.inheritedTypes
    } else {
      conformanceListSyntax = nil
    }
  }

  return SwiftSyntaxMacroExpansion.expandAttachedMacro(
    definition: macro,
    macroRole: MacroRole(rawMacroRole: rawMacroRole),
    attributeNode: attributeNode,
    declarationNode: declarationNode,
    parentDeclNode: parentDeclNode,
    extendedType: extendedType,
    conformanceList: conformanceListSyntax,
    in: context
  )
}

fileprivate extension SyntaxProtocol {
  /// Perform a format if required and then trim any leading/trailing
  /// whitespace.
  func formattedExpansion(_ mode: FormatMode) -> String {
    let formatted: Syntax
    switch mode {
    case .auto:
      formatted = self.formatted()
    case .disabled:
      formatted = Syntax(self)
    }
    return formatted.trimmedDescription(matching: { $0.isWhitespace })
  }
}
