//===--- ConformingMethodList.cpp -----------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/IDE/ConformingMethodList.h"
#include "ExprContextAnalysis.h"
#include "swift/AST/ASTDemangler.h"
#include "swift/AST/GenericEnvironment.h"
#include "swift/AST/NameLookup.h"
#include "swift/AST/USRGeneration.h"
#include "swift/IDE/TypeCheckCompletionCallback.h"
#include "swift/Parse/IDEInspectionCallbacks.h"
#include "swift/Sema/IDETypeChecking.h"
#include "swift/Sema/ConstraintSystem.h"
#include "clang/AST/Attr.h"
#include "clang/AST/Decl.h"

using namespace swift;
using namespace ide;

namespace {
class ConformingMethodListCallbacks : public CodeCompletionCallbacks,
                                      public DoneParsingCallback {
  ArrayRef<const char *> ExpectedTypeNames;
  ConformingMethodListConsumer &Consumer;
  SourceLoc Loc;
  CodeCompletionExpr *CCExpr = nullptr;
  DeclContext *CurDeclContext = nullptr;

  void getMatchingMethods(Type T,
                          llvm::SmallPtrSetImpl<ProtocolDecl*> &expectedTypes,
                          SmallVectorImpl<ValueDecl *> &result);

public:
  ConformingMethodListCallbacks(Parser &P,
                                ArrayRef<const char *> ExpectedTypeNames,
                                ConformingMethodListConsumer &Consumer)
      : CodeCompletionCallbacks(P), DoneParsingCallback(),
        ExpectedTypeNames(ExpectedTypeNames), Consumer(Consumer) {}

  // Only handle callbacks for suffix completions.
  // {
  void completeDotExpr(CodeCompletionExpr *E, SourceLoc DotLoc) override;
  void completePostfixExpr(CodeCompletionExpr *E, bool hasSpace) override;
  // }

  void doneParsing(SourceFile *SrcFile) override;
};

void ConformingMethodListCallbacks::completeDotExpr(CodeCompletionExpr *E,
                                                    SourceLoc DotLoc) {
  CurDeclContext = P.CurDeclContext;
  CCExpr = E;
}

void ConformingMethodListCallbacks::completePostfixExpr(CodeCompletionExpr *E,
                                                        bool hasSpace) {
  CurDeclContext = P.CurDeclContext;
  CCExpr = E;
}

class ConformingMethodListCallback : public TypeCheckCompletionCallback {
public:
  struct Result {
    Type Ty;

    /// Types of variables that were determined in the solution that produced
    /// this result. This in particular includes parameters of closures that
    /// were type-checked with the code completion expression.
    llvm::SmallDenseMap<const VarDecl *, Type> SolutionSpecificVarTypes;
  };
private:
  CodeCompletionExpr *CCExpr;

  SmallVector<Result> Results;

  void sawSolutionImpl(const constraints::Solution &S) override {
    if (!S.hasType(CCExpr->getBase())) {
      return;
    }
    if (Type T = getTypeForCompletion(S, CCExpr->getBase())) {
      llvm::SmallDenseMap<const VarDecl *, Type> SolutionSpecificVarTypes;
      getSolutionSpecificVarTypes(S, SolutionSpecificVarTypes);
      Results.push_back({T, SolutionSpecificVarTypes});
    }
  }

public:
  ConformingMethodListCallback(CodeCompletionExpr *CCExpr) : CCExpr(CCExpr) {}

  ArrayRef<Result> getResults() const { return Results; }
};

void ConformingMethodListCallbacks::doneParsing(SourceFile *SrcFile) {
  if (!CCExpr || !CCExpr->getBase())
    return;

  ConformingMethodListCallback TypeCheckCallback(CCExpr);
  {
    llvm::SaveAndRestore<TypeCheckCompletionCallback *> CompletionCollector(
        Context.CompletionCallback, &TypeCheckCallback);
    typeCheckContextAt(
        TypeCheckASTNodeAtLocContext::declContext(CurDeclContext),
        CCExpr->getLoc());
  }

  if (TypeCheckCallback.getResults().size() != 1) {
    // Either no results or results were ambiguous, which we cannot handle.
    return;
  }
  auto Res = TypeCheckCallback.getResults()[0];
  Type T = Res.Ty;
  WithSolutionSpecificVarTypesRAII VarType(Res.SolutionSpecificVarTypes);

  if (!T || T->is<ErrorType>() || T->is<UnresolvedType>())
    return;

  T = T->getRValueType();
  if (T->hasArchetype())
    T = T->mapTypeOutOfContext();

  // If there are no (instance) members for this type, bail.
  if (!T->mayHaveMembers() || T->is<ModuleType>()) {
    return;
  }

  llvm::SmallPtrSet<ProtocolDecl*, 8> expectedProtocols;
  for (auto Name: ExpectedTypeNames) {
    if (auto *PD = resolveProtocolName(CurDeclContext, Name)) {
      expectedProtocols.insert(PD);
    }
  }

  // Collect the matching methods.
  ConformingMethodListResult result(CurDeclContext, T);
  getMatchingMethods(T, expectedProtocols, result.Members);

  Consumer.handleResult(result);
}

void ConformingMethodListCallbacks::getMatchingMethods(
    Type T, llvm::SmallPtrSetImpl<ProtocolDecl*> &expectedTypes,
    SmallVectorImpl<ValueDecl *> &result) {
  assert(T->mayHaveMembers() && !T->is<ModuleType>());

  class LocalConsumer : public VisibleDeclConsumer {
    ModuleDecl *CurModule;

    /// The type of the parsed expression.
    Type T;

    /// The list of expected types.
    llvm::SmallPtrSetImpl<ProtocolDecl*> &ExpectedTypes;

    /// Result sink to populate.
    SmallVectorImpl<ValueDecl *> &Result;

    /// Returns true if \p VD is a instance method whose return type conforms
    /// to the requested protocols.
    bool isMatchingMethod(ValueDecl *VD) {
      auto *FD = dyn_cast<FuncDecl>(VD);
      if (!FD)
        return false;
      if (FD->isStatic() || FD->isOperator())
        return false;

      auto resultTy = T->getTypeOfMember(CurModule, FD,
                                         FD->getResultInterfaceType());
      if (resultTy->is<ErrorType>())
        return false;

      // The return type conforms to any of the requested protocols.
      for (auto Proto : ExpectedTypes) {
        if (CurModule->conformsToProtocol(resultTy, Proto))
          return true;
      }

      return false;
    }

  public:
    LocalConsumer(DeclContext *DC, Type T,
                  llvm::SmallPtrSetImpl<ProtocolDecl*> &expectedTypes,
                  SmallVectorImpl<ValueDecl *> &result)
        : CurModule(DC->getParentModule()), T(T), ExpectedTypes(expectedTypes),
          Result(result) {}

    void foundDecl(ValueDecl *VD, DeclVisibilityKind reason,
                   DynamicLookupInfo) override {
      if (isMatchingMethod(VD) && !VD->shouldHideFromEditor())
        Result.push_back(VD);
    }

  } LocalConsumer(CurDeclContext, T, expectedTypes, result);

  lookupVisibleMemberDecls(LocalConsumer, MetatypeType::get(T),
                           Loc, CurDeclContext,
                           /*includeInstanceMembers=*/false,
                           /*includeDerivedRequirements*/false,
                           /*includeProtocolExtensionMembers*/true);
}

} // anonymous namespace.

IDEInspectionCallbacksFactory *
swift::ide::makeConformingMethodListCallbacksFactory(
    ArrayRef<const char *> expectedTypeNames,
    ConformingMethodListConsumer &Consumer) {

  // CC callback factory which produces 'ContextInfoCallbacks'.
  class ConformingMethodListCallbacksFactoryImpl
      : public IDEInspectionCallbacksFactory {
    ArrayRef<const char *> ExpectedTypeNames;
    ConformingMethodListConsumer &Consumer;

  public:
    ConformingMethodListCallbacksFactoryImpl(
        ArrayRef<const char *> ExpectedTypeNames,
        ConformingMethodListConsumer &Consumer)
        : ExpectedTypeNames(ExpectedTypeNames), Consumer(Consumer) {}

    Callbacks createCallbacks(Parser &P) override {
      auto Callback = std::make_shared<ConformingMethodListCallbacks>(
          P, ExpectedTypeNames, Consumer);
      return {Callback, Callback};
    }
  };

  return new ConformingMethodListCallbacksFactoryImpl(expectedTypeNames,
                                                      Consumer);
}
