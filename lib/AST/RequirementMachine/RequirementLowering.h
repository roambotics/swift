//===--- RequirementLowering.h - Requirement inference and desugaring -----===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_REQUIREMENTLOWERING_H
#define SWIFT_REQUIREMENTLOWERING_H

#include "swift/AST/Type.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/SmallVector.h"
#include <vector>
#include "Diagnostics.h"

namespace llvm {
  class raw_ostream;
}

namespace swift {

class AssociatedTypeDecl;
class ProtocolDecl;
class ProtocolTypeAlias;
class Requirement;

namespace rewriting {

// Entry points used by AbstractGenericSignatureRequest and
// InferredGenericSignatureRequest; see RequirementLowering.cpp for
// documentation
// comments.

void desugarRequirement(Requirement req,
                        SmallVectorImpl<Requirement> &result,
                        SmallVectorImpl<RequirementError> &errors);

void inferRequirements(Type type, SourceLoc loc, ModuleDecl *module,
                       SmallVectorImpl<StructuralRequirement> &result);

void realizeRequirement(Requirement req, RequirementRepr *reqRepr,
                        ModuleDecl *moduleForInference,
                        SmallVectorImpl<StructuralRequirement> &result,
                        SmallVectorImpl<RequirementError> &errors);

void realizeInheritedRequirements(TypeDecl *decl, Type type,
                                  ModuleDecl *moduleForInference,
                                  SmallVectorImpl<StructuralRequirement> &result,
                                  SmallVectorImpl<RequirementError> &errors);

bool diagnoseRequirementErrors(ASTContext &ctx,
                               ArrayRef<RequirementError> errors,
                               bool allowConcreteGenericParams);

// Defined in ConcreteContraction.cpp.
bool performConcreteContraction(
    ArrayRef<StructuralRequirement> requirements,
    SmallVectorImpl<StructuralRequirement> &result,
    bool debug);

} // end namespace rewriting

} // end namespace swift

#endif
