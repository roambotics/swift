import CASTBridging

// Needed to use SyntaxTransformVisitor's visit method.
@_spi(SyntaxTransformVisitor)
@_spi(ExperimentalLanguageFeatures)
import SwiftSyntax
import SwiftDiagnostics

extension ASTGenVisitor {
  public func visit(_ node: IdentifierTypeSyntax) -> ASTNode {
    let loc = node.bridgedSourceLoc(in: self)

    // If this is the bare 'Any' keyword, produce an empty composition type.
    if node.name.tokenKind == .keyword(.Any) && node.genericArgumentClause == nil {
      return .type(EmptyCompositionTypeRepr_create(self.ctx, loc))
    }

    let id = node.name.bridgedIdentifier(in: self)

    guard let generics = node.genericArgumentClause else {
      return .type(SimpleIdentTypeRepr_create(ctx, loc, id))
    }

    let genericArguments = generics.arguments.lazy.map {
      self.visit($0.argument).rawValue
    }

    return .type(
      GenericIdentTypeRepr_create(
        self.ctx,
        id,
        loc,
        genericArguments.bridgedArray(in: self),
        generics.leftAngle.bridgedSourceLoc(in: self),
        generics.rightAngle.bridgedSourceLoc(in: self)
      )
    )
  }

  public func visit(_ node: MemberTypeSyntax) -> ASTNode {
    // Gather the member components, in decreasing depth order.
    var reverseMemberComponents = [UnsafeMutableRawPointer]()

    var baseType = Syntax(node)
    while let memberType = baseType.as(MemberTypeSyntax.self) {
      let (name, nameLoc) = memberType.name.bridgedIdentifierAndSourceLoc(in: self)

      if let generics = memberType.genericArgumentClause {
        let genericArguments = generics.arguments.lazy.map {
          self.visit($0.argument).rawValue
        }

        reverseMemberComponents.append(
          GenericIdentTypeRepr_create(
            self.ctx,
            name,
            nameLoc,
            genericArguments.bridgedArray(in: self),
            generics.leftAngle.bridgedSourceLoc(in: self),
            generics.rightAngle.bridgedSourceLoc(in: self)
          )
        )
      } else {
        reverseMemberComponents.append(SimpleIdentTypeRepr_create(self.ctx, nameLoc, name))
      }

      baseType = Syntax(memberType.baseType)
    }

    let baseComponent = visit(baseType).rawValue
    let memberComponents = reverseMemberComponents.reversed().bridgedArray(in: self)

    return .type(MemberTypeRepr_create(self.ctx, baseComponent, memberComponents))
  }

  public func visit(_ node: ArrayTypeSyntax) -> ASTNode {
    let elementType = visit(node.element).rawValue
    let lSquareLoc = node.leftSquare.bridgedSourceLoc(in: self)
    let rSquareLoc = node.rightSquare.bridgedSourceLoc(in: self)
    return .type(ArrayTypeRepr_create(self.ctx, elementType, lSquareLoc, rSquareLoc))
  }

  public func visit(_ node: DictionaryTypeSyntax) -> ASTNode {
    let keyType = visit(node.key).rawValue
    let valueType = visit(node.value).rawValue
    let colonLoc = node.colon.bridgedSourceLoc(in: self)
    let lSquareLoc = node.leftSquare.bridgedSourceLoc(in: self)
    let rSquareLoc = node.rightSquare.bridgedSourceLoc(in: self)
    return .type(
      DictionaryTypeRepr_create(self.ctx, keyType, valueType, colonLoc, lSquareLoc, rSquareLoc))
  }

  public func visit(_ node: MetatypeTypeSyntax) -> ASTNode {
    let baseType = visit(node.baseType).rawValue
    let tyLoc = node.metatypeSpecifier.bridgedSourceLoc(in: self)
    if node.metatypeSpecifier.text == "Type" {
      return .type(MetatypeTypeRepr_create(self.ctx, baseType, tyLoc))
    } else {
      assert(node.metatypeSpecifier.text == "Protocol")
      return .type(ProtocolTypeRepr_create(self.ctx, baseType, tyLoc))
    }
  }

  public func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> ASTNode {
    let base = visit(node.wrappedType).rawValue
    let exclaimLoc = node.exclamationMark.bridgedSourceLoc(in: self)
    return .type(ImplicitlyUnwrappedOptionalTypeRepr_create(self.ctx, base, exclaimLoc))
  }

  public func visit(_ node: OptionalTypeSyntax) -> ASTNode {
    let base = visit(node.wrappedType).rawValue
    let questionLoc = node.questionMark.bridgedSourceLoc(in: self)
    return .type(OptionalTypeRepr_create(self.ctx, base, questionLoc))
  }

  public func visit(_ node: PackExpansionTypeSyntax) -> ASTNode {
    let base = visit(node.repetitionPattern).rawValue
    let repeatLoc = node.repeatKeyword.bridgedSourceLoc(in: self)
    return .type(PackExpansionTypeRepr_create(self.ctx, base, repeatLoc))
  }

  public func visit(_ node: TupleTypeSyntax) -> ASTNode {
    .type(
      TupleTypeRepr_create(
        self.ctx,
        self.visit(node.elements),
        node.leftParen.bridgedSourceLoc(in: self),
        node.rightParen.bridgedSourceLoc(in: self)
      )
    )
  }

  public func visit(_ node: CompositionTypeSyntax) -> ASTNode {
    assert(node.elements.count > 1)

    let types = node.elements.lazy.map {
      visit($0.type).rawValue
    }

    return .type(
      CompositionTypeRepr_create(
        self.ctx,
        types.bridgedArray(in: self),
        (node.elements.first?.type).bridgedSourceLoc(in: self),
        (node.elements.first?.ampersand).bridgedSourceLoc(in: self)
      )
    )
  }

  public func visit(_ node: FunctionTypeSyntax) -> ASTNode {
    .type(
      FunctionTypeRepr_create(
        self.ctx,
        // FIXME: Why does `FunctionTypeSyntax` not have a `TupleTypeSyntax` child?
        TupleTypeRepr_create(
          self.ctx,
          self.visit(node.parameters),
          node.leftParen.bridgedSourceLoc(in: self),
          node.rightParen.bridgedSourceLoc(in: self)
        ),
        (node.effectSpecifiers?.asyncSpecifier).bridgedSourceLoc(in: self),
        (node.effectSpecifiers?.throwsSpecifier).bridgedSourceLoc(in: self),
        self.visit(node.effectSpecifiers?.thrownError?.type)?.rawValue,
        node.returnClause.arrow.bridgedSourceLoc(in: self),
        visit(node.returnClause.type).rawValue
      )
    )
  }

  public func visit(_ node: NamedOpaqueReturnTypeSyntax) -> ASTNode {
    let baseTy = visit(node.type).rawValue
    return .type(NamedOpaqueReturnTypeRepr_create(self.ctx, baseTy))
  }

  public func visit(_ node: SomeOrAnyTypeSyntax) -> ASTNode {
    let someOrAnyLoc = node.someOrAnySpecifier.bridgedSourceLoc(in: self)
    let baseTy = visit(node.constraint).rawValue
    if node.someOrAnySpecifier.text == "some" {
      return .type(OpaqueReturnTypeRepr_create(self.ctx, someOrAnyLoc, baseTy))
    } else {
      assert(node.someOrAnySpecifier.text == "any")
      return .type(ExistentialTypeRepr_create(self.ctx, someOrAnyLoc, baseTy))
    }
  }
}

// MARK: - SpecifierTypeRepr/AttrubutedTypeRepr

extension BridgedAttributedTypeSpecifier {
  fileprivate init?(from tokenKind: TokenKind) {
    switch tokenKind {
    case .keyword(.inout): self = .inOut
    case .keyword(.borrowing): self = .borrowing
    case .keyword(.consuming): self = .consuming
    case .keyword(.__shared): self = .legacyShared
    case .keyword(.__owned): self = .legacyOwned
    case .keyword(._const): self = .const
    case .keyword(.isolated): self = .isolated
    default: return nil
    }
  }
}

extension ASTGenVisitor {
  public func visit(_ node: AttributedTypeSyntax) -> ASTNode {
    var type = visit(node.baseType)

    // Handle specifiers.
    if let specifier = node.specifier {
      if let kind = BridgedAttributedTypeSpecifier(from: specifier.tokenKind) {
        type = .type(AttributedTypeSpecifierRepr_create(self.ctx, type.rawValue, kind, specifier.bridgedSourceLoc(in: self)))
      } else {
        self.diagnose(Diagnostic(node: specifier, message: UnexpectedTokenKindError(token: specifier)))
      }
    }

    // Handle type attributes.
    if !node.attributes.isEmpty {
      let typeAttributes = TypeAttributes_create()
      for attributeElt in node.attributes {
        // FIXME: Ignoring #ifs entirely. We want to provide a filtered view,
        // but we don't have that ability right now.
        guard case let .attribute(attribute) = attributeElt else {
          continue
        }

        // Only handle simple attribute names right now.
        guard let identType = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
          continue
        }

        let nameSyntax = identType.name
        var name = nameSyntax.text
        let typeAttrKind = name.withBridgedString { bridgedName in
          TypeAttrKind_fromString(bridgedName)
        }
        let atLoc = attribute.atSign.bridgedSourceLoc(in: self)
        let attrLoc = nameSyntax.bridgedSourceLoc(in: self)
        switch typeAttrKind {
          // SIL attributes
          // FIXME: Diagnose if not in SIL mode? Or should that move to the
          // type checker?
          case .out, .in, .owned, .unowned_inner_pointer, .guaranteed,
               .autoreleased, .callee_owned, .callee_guaranteed, .objc_metatype,
               .sil_weak, .sil_unowned, .inout, .block_storage, .box,
               .dynamic_self, .sil_unmanaged, .error, .direct, .inout_aliasable,
               .in_guaranteed, .in_constant, .captures_generics, .moveOnly:
            fallthrough

          case .autoclosure, .escaping, .noescape, .noDerivative, .async,
            .sendable, .unchecked, ._local, ._noMetadata, .pack_owned,
            .pack_guaranteed, .pack_inout, .pack_out, .pseudogeneric,
            .yields, .yield_once, .yield_many, .thin, .thick, .count,
            .unimplementable:
            TypeAttributes_addSimpleAttr(typeAttributes, typeAttrKind, atLoc, attrLoc)

          case .opened, .pack_element, .differentiable, .convention,
            ._opaqueReturnTypeOf:
            // FIXME: These require more complicated checks
            break
        }
      }

      type = .type(AttributedTypeRepr_create(self.ctx, type.rawValue, typeAttributes))
    }

    return type
  }
}

extension ASTGenVisitor {
  func visit(_ node: TupleTypeElementListSyntax) -> BridgedArrayRef {
    node.lazy.map { element in
      let (firstName, firstNameLoc) = element.firstName.bridgedIdentifierAndSourceLoc(in: self)
      let (secondName, secondNameLoc) = element.secondName.bridgedIdentifierAndSourceLoc(in: self)
      var type = visit(element.type).rawValue
      if let ellipsis = element.ellipsis {
        type = VarargTypeRepr_create(self.ctx, type, ellipsis.bridgedSourceLoc(in: self))
      }

      return BridgedTupleTypeElement(
        Name: firstName,
        NameLoc: firstNameLoc,
        SecondName: secondName,
        SecondNameLoc: secondNameLoc,
        UnderscoreLoc: nil, /*N.B. Only important for SIL*/
        ColonLoc: element.colon.bridgedSourceLoc(in: self),
        Type: type,
        TrailingCommaLoc: element.trailingComma.bridgedSourceLoc(in: self)
      )
    }.bridgedArray(in: self)
  }
}

@_cdecl("swift_ASTGen_buildTypeRepr")
@usableFromInline
func buildTypeRepr(
  diagEnginePtr: UnsafeMutablePointer<UInt8>,
  sourceFilePtr: UnsafeRawPointer,
  typeLocPtr: UnsafePointer<UInt8>,
  dc: UnsafeMutableRawPointer,
  ctx: UnsafeMutableRawPointer,
  endTypeLocPtr: UnsafeMutablePointer<UnsafePointer<UInt8>?>
) -> UnsafeMutableRawPointer? {
  let sourceFile = sourceFilePtr.bindMemory(
    to: ExportedSourceFile.self, capacity: 1
  )

  // Find the type syntax node.
  guard let typeSyntax = findSyntaxNodeInSourceFile(
    sourceFilePtr: sourceFilePtr,
    sourceLocationPtr: typeLocPtr,
    type: TypeSyntax.self,
    wantOutermost: true
  ) else {
    // FIXME: Produce an error
    return nil
  }

  // Fill in the end location.
  endTypeLocPtr.pointee = sourceFile.pointee.buffer.baseAddress!.advanced(by: typeSyntax.endPosition.utf8Offset)

  // Convert the type syntax node.
  return ASTGenVisitor(
    diagnosticEngine: .init(raw: diagEnginePtr),
    sourceBuffer: sourceFile.pointee.buffer,
    declContext: BridgedDeclContext(raw: dc),
    astContext: BridgedASTContext(raw: ctx)
  ).visit(typeSyntax).rawValue
}
