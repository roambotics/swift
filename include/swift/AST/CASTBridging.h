//===--- CASTBridging.h - C header for the AST bridging layer ----*- C -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_C_AST_ASTBRIDGING_H
#define SWIFT_C_AST_ASTBRIDGING_H

#include "swift/Basic/CBasicBridging.h"
#include "swift/Basic/Compiler.h"
#include "swift/Basic/Nullability.h"

// NOTE: DO NOT #include any stdlib headers here. e.g. <stdint.h>. Those are
// part of "Darwin"/"Glibc" module, so when a Swift file imports this header,
// it causes importing the "Darwin"/"Glibc" overlay module. That violates
// layering. i.e. Darwin overlay is created by Swift compiler.

#if __has_attribute(swift_name)
#define SWIFT_NAME(NAME) __attribute__((swift_name(NAME)))
#else
#define SWIFT_NAME(NAME)
#endif

SWIFT_BEGIN_NULLABILITY_ANNOTATIONS
SWIFT_BEGIN_ASSUME_NONNULL

typedef struct {
  const unsigned char *_Nullable data;
  SwiftInt length;
} BridgedString;

typedef struct {
  const void *_Nullable data;
  SwiftInt numElements;
} BridgedArrayRef;

typedef struct BridgedASTContext {
  void *raw;
} BridgedASTContext;

typedef struct BridgedDeclContext {
  void *raw;
} BridgedDeclContext;

typedef struct BridgedSourceLoc {
  const void *_Nullable raw;
} BridgedSourceLoc;

typedef struct {
  BridgedSourceLoc startLoc;
  BridgedSourceLoc endLoc;
} BridgedSourceRange;

typedef struct BridgedIdentifier {
  const void *_Nullable raw;
} BridgedIdentifier;

typedef struct {
  void *start;
  SwiftInt byteLength;
} BridgedCharSourceRange;

typedef struct {
  BridgedIdentifier Name;
  BridgedSourceLoc NameLoc;
  BridgedIdentifier SecondName;
  BridgedSourceLoc SecondNameLoc;
  BridgedSourceLoc UnderscoreLoc;
  BridgedSourceLoc ColonLoc;
  void *Type;
  BridgedSourceLoc TrailingCommaLoc;
} BridgedTupleTypeElement;

typedef enum ENUM_EXTENSIBILITY_ATTR(open) BridgedRequirementReprKind : SwiftInt {
  /// A type bound T : P, where T is a type that depends on a generic
  /// parameter and P is some type that should bound T, either as a concrete
  /// supertype or a protocol to which T must conform.
  BridgedRequirementReprKindTypeConstraint,

  /// A same-type requirement T == U, where T and U are types that shall be
  /// equivalent.
  BridgedRequirementReprKindSameType,

  /// A layout bound T : L, where T is a type that depends on a generic
  /// parameter and L is some layout specification that should bound T.
  BridgedRequirementReprKindLayoutConstraint,

  // Note: there is code that packs this enum in a 2-bit bitfield.  Audit users
  // when adding enumerators.
} BridgedRequirementReprKind;

typedef struct {
  BridgedSourceLoc SeparatorLoc;
  BridgedRequirementReprKind Kind;
  void *FirstType;
  void *SecondType;
  // FIXME: Handle Layout Requirements
} BridgedRequirementRepr;

/// Diagnostic severity when reporting diagnostics.
typedef enum ENUM_EXTENSIBILITY_ATTR(open) BridgedDiagnosticSeverity : SwiftInt {
  BridgedFatalError,
  BridgedError,
  BridgedWarning,
  BridgedRemark,
  BridgedNote,
} BridgedDiagnosticSeverity;

typedef struct BridgedDiagnostic {
  void *raw;
} BridgedDiagnostic;

typedef struct BridgedDiagnosticEngine {
  void *raw;
} BridgedDiagnosticEngine;

typedef enum ENUM_EXTENSIBILITY_ATTR(open) BridgedMacroDefinitionKind : SwiftInt {
  /// An expanded macro.
  BridgedExpandedMacro = 0,
  /// An external macro, spelled with either the old spelling (Module.Type)
  /// or the new spelling `#externalMacro(module: "Module", type: "Type")`.
  BridgedExternalMacro,
  /// The builtin definition for "externalMacro".
  BridgedBuiltinExternalMacro
} BridgedMacroDefinitionKind;

/// Bridged parameter specifiers
typedef enum ENUM_EXTENSIBILITY_ATTR(open) BridgedAttributedTypeSpecifier : SwiftInt {
  BridgedAttributedTypeSpecifierInOut,
  BridgedAttributedTypeSpecifierBorrowing,
  BridgedAttributedTypeSpecifierConsuming,
  BridgedAttributedTypeSpecifierLegacyShared,
  BridgedAttributedTypeSpecifierLegacyOwned,
  BridgedAttributedTypeSpecifierConst,
  BridgedAttributedTypeSpecifierIsolated,
} BridgedAttributedTypeSpecifier;

// Bridged type attribute kinds, which mirror TypeAttrKind exactly.
typedef enum ENUM_EXTENSIBILITY_ATTR(closed) BridgedTypeAttrKind : SwiftInt {
  BridgedTypeAttrKind_autoclosure,
  BridgedTypeAttrKind_convention,
  BridgedTypeAttrKind_noescape,
  BridgedTypeAttrKind_escaping,
  BridgedTypeAttrKind_differentiable,
  BridgedTypeAttrKind_noDerivative,
  BridgedTypeAttrKind_async,
  BridgedTypeAttrKind_Sendable,
  BridgedTypeAttrKind_unchecked,
  BridgedTypeAttrKind__local,
  BridgedTypeAttrKind__noMetadata,
  BridgedTypeAttrKind__opaqueReturnTypeOf,
  BridgedTypeAttrKind_block_storage,
  BridgedTypeAttrKind_box,
  BridgedTypeAttrKind_dynamic_self,
  BridgedTypeAttrKind_sil_weak,
  BridgedTypeAttrKind_sil_unowned,
  BridgedTypeAttrKind_sil_unmanaged,
  BridgedTypeAttrKind_error,
  BridgedTypeAttrKind_out,
  BridgedTypeAttrKind_direct,
  BridgedTypeAttrKind_in,
  BridgedTypeAttrKind_inout,
  BridgedTypeAttrKind_inout_aliasable,
  BridgedTypeAttrKind_in_guaranteed,
  BridgedTypeAttrKind_in_constant,
  BridgedTypeAttrKind_pack_owned,
  BridgedTypeAttrKind_pack_guaranteed,
  BridgedTypeAttrKind_pack_inout,
  BridgedTypeAttrKind_pack_out,
  BridgedTypeAttrKind_owned,
  BridgedTypeAttrKind_unowned_inner_pointer,
  BridgedTypeAttrKind_guaranteed,
  BridgedTypeAttrKind_autoreleased,
  BridgedTypeAttrKind_callee_owned,
  BridgedTypeAttrKind_callee_guaranteed,
  BridgedTypeAttrKind_objc_metatype,
  BridgedTypeAttrKind_opened,
  BridgedTypeAttrKind_pack_element,
  BridgedTypeAttrKind_pseudogeneric,
  BridgedTypeAttrKind_unimplementable,
  BridgedTypeAttrKind_yields,
  BridgedTypeAttrKind_yield_once,
  BridgedTypeAttrKind_yield_many,
  BridgedTypeAttrKind_captures_generics,
  BridgedTypeAttrKind_moveOnly,
  BridgedTypeAttrKind_thin,
  BridgedTypeAttrKind_thick,
  BridgedTypeAttrKind_Count
} BridgedTypeAttrKind;

typedef enum ENUM_EXTENSIBILITY_ATTR(open) ASTNodeKind : SwiftInt {
  ASTNodeKindExpr,
  ASTNodeKindStmt,
  ASTNodeKindDecl
} ASTNodeKind;

typedef struct BridgedASTNode {
  void *ptr;
  ASTNodeKind kind;
} BridgedASTNode;

typedef struct BridgedFuncDecl {
  BridgedDeclContext declContext;
  void *funcDecl;
  void *decl;
} BridgedFuncDecl;

typedef struct BridgedDeclContextAndDecl {
  BridgedDeclContext asDeclContext;
  void *asDecl;
} BridgedDeclContextAndDecl;

typedef struct BridgedTypeAttributes {
  void *raw;
} BridgedTypeAttributes;

struct BridgedIdentifierAndSourceLoc {
  BridgedIdentifier name;
  BridgedSourceLoc nameLoc;
};

#ifdef __cplusplus
extern "C" {

#define _Bool bool
#endif

// Diagnostics

/// Create a new diagnostic with the given severity, location, and diagnostic
/// text.
///
/// \returns a diagnostic instance that can be extended with additional
/// information and then must be finished via \c SwiftDiagnostic_finish.
BridgedDiagnostic Diagnostic_create(BridgedDiagnosticEngine cDiags,
                                    BridgedDiagnosticSeverity severity,
                                    BridgedSourceLoc cLoc, BridgedString cText);

/// Highlight a source range as part of the diagnostic.
void Diagnostic_highlight(BridgedDiagnostic cDiag, BridgedSourceLoc cStartLoc,
                          BridgedSourceLoc cEndLoc);

/// Add a Fix-It to replace a source range as part of the diagnostic.
void Diagnostic_fixItReplace(BridgedDiagnostic cDiag,
                             BridgedSourceLoc cStartLoc,
                             BridgedSourceLoc cEndLoc,
                             BridgedString cReplaceText);

/// Finish the given diagnostic and emit it.
void Diagnostic_finish(BridgedDiagnostic cDiag);

BridgedIdentifier ASTContext_getIdentifier(BridgedASTContext cContext,
                                           BridgedString cStr);

_Bool ASTContext_langOptsHasFeature(BridgedASTContext cContext,
                                    BridgedFeature feature);

SWIFT_NAME("TopLevelCodeDecl_createStmt(astContext:declContext:startLoc:"
           "statement:endLoc:)")
void *TopLevelCodeDecl_createStmt(BridgedASTContext cContext,
                                  BridgedDeclContext cDeclContext,
                                  BridgedSourceLoc cStartLoc, void *statement,
                                  BridgedSourceLoc cEndLoc);

SWIFT_NAME("TopLevelCodeDecl_createExpr(astContext:declContext:startLoc:"
           "expression:endLoc:)")
void *TopLevelCodeDecl_createExpr(BridgedASTContext cContext,
                                  BridgedDeclContext cDeclContext,
                                  BridgedSourceLoc cStartLoc, void *expression,
                                  BridgedSourceLoc cEndLoc);

void *ReturnStmt_create(BridgedASTContext cContext, BridgedSourceLoc cLoc,
                        void *_Nullable expr);

void *SequenceExpr_create(BridgedASTContext cContext, BridgedArrayRef exprs);

void *TupleExpr_create(BridgedASTContext cContext, BridgedSourceLoc cLParen,
                       BridgedArrayRef subs, BridgedArrayRef names,
                       BridgedArrayRef cNameLocs, BridgedSourceLoc cRParen);

void *FunctionCallExpr_create(BridgedASTContext cContext, void *fn, void *args);

void *IdentifierExpr_create(BridgedASTContext cContext, BridgedIdentifier base,
                            BridgedSourceLoc cLoc);

void *StringLiteralExpr_create(BridgedASTContext cContext, BridgedString cStr,
                               BridgedSourceLoc cTokenLoc);

void *IntegerLiteralExpr_create(BridgedASTContext cContext, BridgedString cStr,
                                BridgedSourceLoc cTokenLoc);

void *BooleanLiteralExpr_create(BridgedASTContext cContext, _Bool value,
                                BridgedSourceLoc cTokenLoc);

SWIFT_NAME("NilLiteralExpr_create(astContext:nilKeywordLoc:)")
void *NilLiteralExpr_create(BridgedASTContext cContext,
                            BridgedSourceLoc cNilKeywordLoc);

void *ArrayExpr_create(BridgedASTContext cContext, BridgedSourceLoc cLLoc,
                       BridgedArrayRef elements, BridgedArrayRef commas,
                       BridgedSourceLoc cRLoc);

SWIFT_NAME("VarDecl_create(astContext:declContext:bindingKeywordLoc:nameExpr:"
           "initializer:isStatic:isLet:)")
void *VarDecl_create(BridgedASTContext cContext,
                     BridgedDeclContext cDeclContext,
                     BridgedSourceLoc cBindingKeywordLoc, void *opaqueNameExpr,
                     void *opaqueInitExpr, _Bool isStatic, _Bool isLet);

void *SingleValueStmtExpr_createWithWrappedBranches(
    BridgedASTContext cContext, void *S, BridgedDeclContext cDeclContext,
    _Bool mustBeExpr);

void *IfStmt_create(BridgedASTContext cContext, BridgedSourceLoc cIfLoc,
                    void *cond, void *_Nullable then, BridgedSourceLoc cElseLoc,
                    void *_Nullable elseStmt);

void *BraceStmt_create(BridgedASTContext cContext, BridgedSourceLoc cLBLoc,
                       BridgedArrayRef elements, BridgedSourceLoc cRBLoc);

BridgedSourceLoc SourceLoc_advanced(BridgedSourceLoc cLoc, SwiftInt len);

SWIFT_NAME("ParamDecl_create(astContext:declContext:specifierLoc:firstName:"
           "firstNameLoc:secondName:secondNameLoc:type:defaultValue:)")
void *
ParamDecl_create(BridgedASTContext cContext, BridgedDeclContext cDeclContext,
                 BridgedSourceLoc cSpecifierLoc, BridgedIdentifier cFirstName,
                 BridgedSourceLoc cFirstNameLoc, BridgedIdentifier cSecondName,
                 BridgedSourceLoc cSecondNameLoc, void *_Nullable opaqueType,
                 void *_Nullable opaqueDefaultValue);

SWIFT_NAME("AbstractFunctionDecl_setBody(_:ofDecl:)")
void AbstractFunctionDecl_setBody(void *opaqueBody, void *opaqueDecl);

SWIFT_NAME("FuncDecl_create(astContext:declContext:staticLoc:funcKeywordLoc:"
           "name:nameLoc:genericParamList:parameterList:asyncSpecifierLoc:"
           "throwsSpecifierLoc:thrownType:returnType:genericWhereClause:)")
struct BridgedDeclContextAndDecl
FuncDecl_create(BridgedASTContext cContext, BridgedDeclContext cDeclContext,
                BridgedSourceLoc cStaticLoc, BridgedSourceLoc cFuncKeywordLoc,
                BridgedIdentifier cName, BridgedSourceLoc cNameLoc,
                void *_Nullable opaqueGenericParamList,
                void *opaqueParameterList, BridgedSourceLoc cAsyncLoc,
                BridgedSourceLoc cThrowsLoc, void *_Nullable opaqueThrownType,
                void *_Nullable opaqueReturnType,
                void *_Nullable opaqueGenericWhereClause);

SWIFT_NAME("ConstructorDecl_create(astContext:declContext:initKeywordLoc:"
           "failabilityMarkLoc:isIUO:genericParamList:parameterList:"
           "asyncSpecifierLoc:throwsSpecifierLoc:thrownType:genericWhereClause:)")
BridgedDeclContextAndDecl ConstructorDecl_create(
    BridgedASTContext cContext, BridgedDeclContext cDeclContext,
    BridgedSourceLoc cInitKeywordLoc, BridgedSourceLoc cFailabilityMarkLoc,
    _Bool isIUO, void *_Nullable opaqueGenericParams, void *opaqueParameterList,
    BridgedSourceLoc cAsyncLoc, BridgedSourceLoc cThrowsLoc,
    void *_Nullable opaqueThrownType,
    void *_Nullable opaqueGenericWhereClause);

SWIFT_NAME("DestructorDecl_create(astContext:declContext:deinitKeywordLoc:)")
BridgedDeclContextAndDecl
DestructorDecl_create(BridgedASTContext cContext,
                      BridgedDeclContext cDeclContext,
                      BridgedSourceLoc cDeinitKeywordLoc);

void *SimpleIdentTypeRepr_create(BridgedASTContext cContext,
                                 BridgedSourceLoc cLoc, BridgedIdentifier id);

void *UnresolvedDotExpr_create(BridgedASTContext cContext, void *base,
                               BridgedSourceLoc cDotLoc, BridgedIdentifier name,
                               BridgedSourceLoc cNameLoc);

void *ClosureExpr_create(BridgedASTContext cContext, void *body,
                         BridgedDeclContext cDeclContext);

SWIFT_NAME(
    "TypeAliasDecl_create(astContext:declContext:typealiasKeywordLoc:name:"
    "nameLoc:genericParamList:equalLoc:underlyingType:genericWhereClause:)")
void *TypeAliasDecl_create(BridgedASTContext cContext,
                           BridgedDeclContext cDeclContext,
                           BridgedSourceLoc cAliasKeywordLoc,
                           BridgedIdentifier cName, BridgedSourceLoc cNameLoc,
                           void *_Nullable opaqueGenericParamList,
                           BridgedSourceLoc cEqualLoc,
                           void *opaqueUnderlyingType,
                           void *_Nullable opaqueGenericWhereClause);

SWIFT_NAME("IterableDeclContext_setParsedMembers(_:ofDecl:)")
void IterableDeclContext_setParsedMembers(BridgedArrayRef members,
                                          void *opaqueDecl);

SWIFT_NAME("EnumDecl_create(astContext:declContext:enumKeywordLoc:name:nameLoc:"
           "genericParamList:inheritedTypes:genericWhereClause:braceRange:)")
BridgedDeclContextAndDecl EnumDecl_create(
    BridgedASTContext cContext, BridgedDeclContext cDeclContext,
    BridgedSourceLoc cEnumKeywordLoc, BridgedIdentifier cName,
    BridgedSourceLoc cNameLoc, void *_Nullable opaqueGenericParamList,
    BridgedArrayRef cInheritedTypes, void *_Nullable opaqueGenericWhereClause,
    BridgedSourceRange cBraceRange);

SWIFT_NAME("EnumCaseDecl_create(declContext:caseKeywordLoc:elements:)")
void *EnumCaseDecl_create(BridgedDeclContext cDeclContext,
                          BridgedSourceLoc cCaseKeywordLoc,
                          BridgedArrayRef cElements);

SWIFT_NAME("EnumElementDecl_create(astContext:declContext:name:nameLoc:"
           "parameterList:equalsLoc:rawValue:)")
void *EnumElementDecl_create(BridgedASTContext cContext,
                             BridgedDeclContext cDeclContext,
                             BridgedIdentifier cName, BridgedSourceLoc cNameLoc,
                             void *_Nullable opaqueParameterList,
                             BridgedSourceLoc cEqualsLoc,
                             void *_Nullable opaqueRawValue);

SWIFT_NAME(
    "StructDecl_create(astContext:declContext:structKeywordLoc:name:nameLoc:"
    "genericParamList:inheritedTypes:genericWhereClause:braceRange:)")
BridgedDeclContextAndDecl StructDecl_create(
    BridgedASTContext cContext, BridgedDeclContext cDeclContext,
    BridgedSourceLoc cStructKeywordLoc, BridgedIdentifier cName,
    BridgedSourceLoc cNameLoc, void *_Nullable opaqueGenericParamList,
    BridgedArrayRef cInheritedTypes, void *_Nullable opaqueGenericWhereClause,
    BridgedSourceRange cBraceRange);

SWIFT_NAME(
    "ClassDecl_create(astContext:declContext:classKeywordLoc:name:nameLoc:"
    "genericParamList:inheritedTypes:genericWhereClause:braceRange:isActor:)")
BridgedDeclContextAndDecl ClassDecl_create(
    BridgedASTContext cContext, BridgedDeclContext cDeclContext,
    BridgedSourceLoc cClassKeywordLoc, BridgedIdentifier cName,
    BridgedSourceLoc cNameLoc, void *_Nullable opaqueGenericParamList,
    BridgedArrayRef cInheritedTypes, void *_Nullable opaqueGenericWhereClause,
    BridgedSourceRange cBraceRange, _Bool isActor);

SWIFT_NAME("ProtocolDecl_create(astContext:declContext:protocolKeywordLoc:name:"
           "nameLoc:primaryAssociatedTypeNames:inheritedTypes:"
           "genericWhereClause:braceRange:)")
BridgedDeclContextAndDecl ProtocolDecl_create(
    BridgedASTContext cContext, BridgedDeclContext cDeclContext,
    BridgedSourceLoc cProtocolKeywordLoc, BridgedIdentifier cName,
    BridgedSourceLoc cNameLoc, BridgedArrayRef cPrimaryAssociatedTypeNames,
    BridgedArrayRef cInheritedTypes, void *_Nullable opaqueGenericWhereClause,
    BridgedSourceRange cBraceRange);

SWIFT_NAME(
    "AssociatedTypeDecl_create(astContext:declContext:associatedtypeKeywordLoc:"
    "name:nameLoc:inheritedTypes:defaultType:genericWhereClause:)")
void *AssociatedTypeDecl_create(BridgedASTContext cContext,
                                BridgedDeclContext cDeclContext,
                                BridgedSourceLoc cAssociatedtypeKeywordLoc,
                                BridgedIdentifier cName,
                                BridgedSourceLoc cNameLoc,
                                BridgedArrayRef cInheritedTypes,
                                void *_Nullable opaqueDefaultType,
                                void *_Nullable opaqueGenericWhereClause);

SWIFT_NAME("ExtensionDecl_create(astContext:declContext:extensionKeywordLoc:"
           "extendedType:inheritedTypes:genericWhereClause:braceRange:)")
BridgedDeclContextAndDecl ExtensionDecl_create(
    BridgedASTContext cContext, BridgedDeclContext cDeclContext,
    BridgedSourceLoc cExtensionKeywordLoc, void *opaqueExtendedType,
    BridgedArrayRef cInheritedTypes, void *_Nullable opaqueGenericWhereClause,
    BridgedSourceRange cBraceRange);

typedef enum ENUM_EXTENSIBILITY_ATTR(closed) {
  BridgedOperatorFixityInfix,
  BridgedOperatorFixityPrefix,
  BridgedOperatorFixityPostfix,
} BridgedOperatorFixity;

SWIFT_NAME(
    "OperatorDecl_create(astContext:declContext:fixity:operatorKeywordLoc:name:"
    "nameLoc:colonLoc:precedenceGroupName:PrecedenceGroupLoc:)")
void *OperatorDecl_create(BridgedASTContext cContext,
                          BridgedDeclContext cDeclContext,
                          BridgedOperatorFixity cFixity,
                          BridgedSourceLoc cOperatorKeywordLoc,
                          BridgedIdentifier cName, BridgedSourceLoc cNameLoc,
                          BridgedSourceLoc cColonLoc,
                          BridgedIdentifier cPrecedenceGroupName,
                          BridgedSourceLoc cPrecedenceGroupLoc);

typedef enum ENUM_EXTENSIBILITY_ATTR(closed) {
  BridgedAssociativityNone,
  BridgedAssociativityLeft,
  BridgedAssociativityRight,
} BridgedAssociativity;

SWIFT_NAME("PrecedenceGroupDecl_create(declContext:precedencegroupKeywordLoc:"
           "name:nameLoc:leftBraceLoc:associativityLabelLoc:"
           "associativityValueLoc:associativity:assignmentLabelLoc:"
           "assignmentValueLoc:isAssignment:higherThanKeywordLoc:"
           "higherThanNames:lowerThanKeywordLoc:lowerThanNames:rightBraceLoc:)")
void *PrecedenceGroupDecl_create(
    BridgedDeclContext cDeclContext,
    BridgedSourceLoc cPrecedencegroupKeywordLoc, BridgedIdentifier cName,
    BridgedSourceLoc cNameLoc, BridgedSourceLoc cLeftBraceLoc,
    BridgedSourceLoc cAssociativityKeywordLoc,
    BridgedSourceLoc cAssociativityValueLoc,
    BridgedAssociativity cAssociativity, BridgedSourceLoc cAssignmentKeywordLoc,
    BridgedSourceLoc cAssignmentValueLoc, _Bool isAssignment,
    BridgedSourceLoc cHigherThanKeywordLoc, BridgedArrayRef cHigherThanNames,
    BridgedSourceLoc cLowerThanKeywordLoc, BridgedArrayRef cLowerThanNames,
    BridgedSourceLoc cRightBraceLoc);

typedef enum ENUM_EXTENSIBILITY_ATTR(open) {
  BridgedImportKindModule,
  BridgedImportKindType,
  BridgedImportKindStruct,
  BridgedImportKindClass,
  BridgedImportKindEnum,
  BridgedImportKindProtocol,
  BridgedImportKindVar,
  BridgedImportKindFunc,
} BridgedImportKind;

SWIFT_NAME("ImportDecl_create(astContext:declContext:importKeywordLoc:"
           "importKind:importKindLoc:path:)")
void *ImportDecl_create(BridgedASTContext cContext,
                        BridgedDeclContext cDeclContext,
                        BridgedSourceLoc cImportKeywordLoc,
                        BridgedImportKind cImportKind,
                        BridgedSourceLoc cImportKindLoc,
                        BridgedArrayRef cImportPathElements);

SWIFT_NAME("GenericParamList_create(astContext:leftAngleLoc:parameters:"
           "genericWhereClause:rightAngleLoc:)")
void *GenericParamList_create(BridgedASTContext cContext,
                              BridgedSourceLoc cLeftAngleLoc,
                              BridgedArrayRef cParameters,
                              void *_Nullable opaqueGenericWhereClause,
                              BridgedSourceLoc cRightAngleLoc);

SWIFT_NAME("GenericTypeParamDecl_create(astContext:declContext:eachKeywordLoc:"
           "name:nameLoc:inheritedType:index:)")
void *GenericTypeParamDecl_create(BridgedASTContext cContext,
                                  BridgedDeclContext cDeclContext,
                                  BridgedSourceLoc cEachLoc,
                                  BridgedIdentifier cName,
                                  BridgedSourceLoc cNameLoc,
                                  void *_Nullable opaqueInheritedType,
                                  SwiftInt index);

SWIFT_NAME(
    "TrailingWhereClause_create(astContext:whereKeywordLoc:requirements:)")
void *TrailingWhereClause_create(BridgedASTContext cContext,
                                 BridgedSourceLoc cWhereKeywordLoc,
                                 BridgedArrayRef cRequirements);

SWIFT_NAME(
    "ParameterList_create(astContext:leftParenLoc:parameters:rightParenLoc:)")
void *ParameterList_create(BridgedASTContext cContext,
                           BridgedSourceLoc cLeftParenLoc,
                           BridgedArrayRef cParameters,
                           BridgedSourceLoc cRightParenLoc);

BridgedTypeAttrKind TypeAttrKind_fromString(BridgedString cStr);
BridgedTypeAttributes TypeAttributes_create(void);
void TypeAttributes_addSimpleAttr(BridgedTypeAttributes cAttributes,
                                  BridgedTypeAttrKind kind,
                                  BridgedSourceLoc cAtLoc,
                                  BridgedSourceLoc cAttrLoc);

void *ArrayTypeRepr_create(BridgedASTContext cContext, void *base,
                           BridgedSourceLoc cLSquareLoc,
                           BridgedSourceLoc cRSquareLoc);
void *AttributedTypeRepr_create(BridgedASTContext cContext, void *base,
                                BridgedTypeAttributes cAttributes);
void *
AttributedTypeSpecifierRepr_create(BridgedASTContext cContext, void *base,
                                   BridgedAttributedTypeSpecifier specifier,
                                   BridgedSourceLoc cSpecifierLoc);
void *CompositionTypeRepr_create(BridgedASTContext cContext,
                                 BridgedArrayRef types,
                                 BridgedSourceLoc cFirstTypeLoc,
                                 BridgedSourceLoc cFirstAmpLoc);
void *DictionaryTypeRepr_create(BridgedASTContext cContext, void *keyType,
                                void *valueType, BridgedSourceLoc cLSquareLoc,
                                BridgedSourceLoc cColonloc,
                                BridgedSourceLoc cRSquareLoc);
void *EmptyCompositionTypeRepr_create(BridgedASTContext cContext,
                                      BridgedSourceLoc cAnyLoc);
void *FunctionTypeRepr_create(BridgedASTContext cContext, void *argsTy,
                              BridgedSourceLoc cAsyncLoc,
                              BridgedSourceLoc cThrowsLoc,
                              void * _Nullable thrownType,
                              BridgedSourceLoc cArrowLoc, void *returnType);
void *GenericIdentTypeRepr_create(BridgedASTContext cContext,
                                  BridgedIdentifier name,
                                  BridgedSourceLoc cNameLoc,
                                  BridgedArrayRef genericArgs,
                                  BridgedSourceLoc cLAngleLoc,
                                  BridgedSourceLoc cRAngleLoc);
void *OptionalTypeRepr_create(BridgedASTContext cContext, void *base,
                              BridgedSourceLoc cQuestionLoc);
void *ImplicitlyUnwrappedOptionalTypeRepr_create(
    BridgedASTContext cContext, void *base, BridgedSourceLoc cExclamationLoc);
void *MemberTypeRepr_create(BridgedASTContext cContext, void *baseComponent,
                            BridgedArrayRef bridgedMemberComponents);
void *MetatypeTypeRepr_create(BridgedASTContext cContext, void *baseType,
                              BridgedSourceLoc cTypeLoc);
void *ProtocolTypeRepr_create(BridgedASTContext cContext, void *baseType,
                              BridgedSourceLoc cProtoLoc);
void *PackExpansionTypeRepr_create(BridgedASTContext cContext, void *base,
                                   BridgedSourceLoc cRepeatLoc);
void *TupleTypeRepr_create(BridgedASTContext cContext, BridgedArrayRef elements,
                           BridgedSourceLoc cLParenLoc,
                           BridgedSourceLoc cRParenLoc);
void *NamedOpaqueReturnTypeRepr_create(BridgedASTContext cContext,
                                       void *baseTy);
void *OpaqueReturnTypeRepr_create(BridgedASTContext cContext,
                                  BridgedSourceLoc cOpaqueLoc, void *baseTy);
void *ExistentialTypeRepr_create(BridgedASTContext cContext,
                                 BridgedSourceLoc cAnyLoc, void *baseTy);
void *VarargTypeRepr_create(BridgedASTContext cContext, void *base,
                            BridgedSourceLoc cEllipsisLoc);

void TopLevelCodeDecl_dump(void *decl);
void Expr_dump(void *expr);
void Decl_dump(void *decl);
void Stmt_dump(void *statement);
void Type_dump(void *type);

//===----------------------------------------------------------------------===//
// Plugins
//===----------------------------------------------------------------------===//

typedef void *PluginHandle;
typedef const void *PluginCapabilityPtr;

/// Set a capability data to the plugin object. Since the data is just a opaque
/// pointer, it's not used in AST at all.
void Plugin_setCapability(PluginHandle handle, PluginCapabilityPtr _Nullable data);

/// Get a capability data set by \c Plugin_setCapability .
PluginCapabilityPtr _Nullable Plugin_getCapability(PluginHandle handle);

/// Get the executable file path of the plugin.
const char *Plugin_getExecutableFilePath(PluginHandle handle);

/// Lock the plugin. Clients should lock it during sending and recving the
/// response.
void Plugin_lock(PluginHandle handle);

/// Unlock the plugin.
void Plugin_unlock(PluginHandle handle);

/// Launch the plugin if it's not running.
_Bool Plugin_spawnIfNeeded(PluginHandle handle);

/// Sends the message to the plugin, returns true if there was an error.
/// Clients should receive the response  by \c Plugin_waitForNextMessage .
_Bool Plugin_sendMessage(PluginHandle handle, const BridgedData data);

/// Receive a message from the plugin.
_Bool Plugin_waitForNextMessage(PluginHandle handle, BridgedData *data);

#ifdef __cplusplus
}
#endif

SWIFT_END_ASSUME_NONNULL
SWIFT_END_NULLABILITY_ANNOTATIONS

#undef SWIFT_NAME

#endif // SWIFT_C_AST_ASTBRIDGING_H
