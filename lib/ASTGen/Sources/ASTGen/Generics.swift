import CASTBridging
import CBasicBridging

// Needed to use SyntaxTransformVisitor's visit method.
@_spi(SyntaxTransformVisitor)
import SwiftSyntax

extension ASTGenVisitor {
  func visit(_ node: GenericParameterClauseSyntax) -> ASTNode {
    .misc(
      GenericParamList_create(
        astContext: self.ctx,
        leftAngleLoc: node.leftAngle.bridgedSourceLoc(in: self),
        parameters: node.parameters.lazy.map { self.visit($0).rawValue }.bridgedArray(in: self),
        genericWhereClause: self.visit(node.genericWhereClause)?.rawValue,
        rightAngleLoc: node.rightAngle.bridgedSourceLoc(in: self)
      )
    )
  }

  func visit(_ node: GenericParameterSyntax) -> ASTNode {
    let (name, nameLoc) = node.name.bridgedIdentifierAndSourceLoc(in: self)

    var genericParameterIndex: Int?
    for (index, sibling) in (node.parent?.as(GenericParameterListSyntax.self) ?? []).enumerated() {
      if sibling == node {
        genericParameterIndex = index
        break
      }
    }
    guard let genericParameterIndex = genericParameterIndex else {
      preconditionFailure("Node not part of the parent?")
    }

    return .decl(
      GenericTypeParamDecl_create(
        astContext: self.ctx,
        declContext: self.declContext,
        eachKeywordLoc: node.eachKeyword.bridgedSourceLoc(in: self),
        name: name,
        nameLoc: nameLoc,
        inheritedType: self.visit(node.inheritedType)?.rawValue,
        index: SwiftInt(genericParameterIndex)
      )
    )
  }

  func visit(_ node: GenericWhereClauseSyntax) -> ASTNode {
    let requirements = node.requirements.lazy.map {
      switch $0.requirement {
      case .conformanceRequirement(let conformance):
        return BridgedRequirementRepr(
          SeparatorLoc: conformance.colon.bridgedSourceLoc(in: self),
          Kind: .typeConstraint,
          FirstType: self.visit(conformance.leftType).rawValue,
          SecondType: self.visit(conformance.rightType).rawValue
        )
      case .sameTypeRequirement(let sameType):
        return BridgedRequirementRepr(
          SeparatorLoc: sameType.equal.bridgedSourceLoc(in: self),
          Kind: .sameType,
          FirstType: self.visit(sameType.leftType).rawValue,
          SecondType: self.visit(sameType.rightType).rawValue
        )
      case .layoutRequirement(_):
        // FIXME: Implement layout requirement translation.
        fatalError("Translation of layout requirements not implemented!")
      }
    }

    return .misc(
      TrailingWhereClause_create(
        astContext: self.ctx,
        whereKeywordLoc: node.whereKeyword.bridgedSourceLoc(in: self),
        requirements: requirements.bridgedArray(in: self)
      )
    )
  }
}
