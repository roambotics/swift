//===--- Requirement.cpp - Generic requirement ----------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file implements the Requirement class.
//
//===----------------------------------------------------------------------===//

#include "swift/AST/Requirement.h"
#include "swift/AST/Decl.h"
#include "swift/AST/GenericSignature.h"
#include "swift/AST/Module.h"
#include "swift/AST/Types.h"

using namespace swift;

bool Requirement::hasError() const {
  if (getFirstType()->hasError())
    return true;

  if (getKind() != RequirementKind::Layout && getSecondType()->hasError())
    return true;

  return false;
}

bool Requirement::isCanonical() const {
  if (!getFirstType()->isCanonical())
    return false;

  switch (getKind()) {
  case RequirementKind::SameShape:
  case RequirementKind::Conformance:
  case RequirementKind::SameType:
  case RequirementKind::Superclass:
    if (!getSecondType()->isCanonical())
      return false;
    break;

  case RequirementKind::Layout:
    break;
  }

  return true;
}

/// Get the canonical form of this requirement.
Requirement Requirement::getCanonical() const {
  Type firstType = getFirstType()->getCanonicalType();

  switch (getKind()) {
  case RequirementKind::SameShape:
  case RequirementKind::Conformance:
  case RequirementKind::SameType:
  case RequirementKind::Superclass: {
    Type secondType = getSecondType()->getCanonicalType();
    return Requirement(getKind(), firstType, secondType);
  }

  case RequirementKind::Layout:
    return Requirement(getKind(), firstType, getLayoutConstraint());
  }
  llvm_unreachable("Unhandled RequirementKind in switch");
}

ProtocolDecl *Requirement::getProtocolDecl() const {
  assert(getKind() == RequirementKind::Conformance);
  return getSecondType()->castTo<ProtocolType>()->getDecl();
}

CheckRequirementResult Requirement::checkRequirement(
    SmallVectorImpl<Requirement> &subReqs,
    bool allowMissing) const {
  if (hasError())
    return CheckRequirementResult::SubstitutionFailure;

  auto firstType = getFirstType();

  auto expandPackRequirement = [&](PackType *packType) {
    for (auto eltType : packType->getElementTypes()) {
      // FIXME: Doesn't seem right
      if (auto *expansionType = eltType->getAs<PackExpansionType>())
        eltType = expansionType->getPatternType();

      auto kind = getKind();
      if (kind == RequirementKind::Layout) {
        subReqs.emplace_back(kind, eltType,
                             getLayoutConstraint());
      } else {
        subReqs.emplace_back(kind, eltType,
                             getSecondType());
      }
    }
    return CheckRequirementResult::PackRequirement;
  };

  switch (getKind()) {
  case RequirementKind::Conformance: {
    if (auto packType = firstType->getAs<PackType>()) {
      return expandPackRequirement(packType);
    }

    auto *proto = getProtocolDecl();
    auto *module = proto->getParentModule();
    auto conformance = module->lookupConformance(
        firstType, proto, allowMissing);
    if (!conformance)
      return CheckRequirementResult::RequirementFailure;

    auto condReqs = conformance.getConditionalRequirements();
    if (condReqs.empty())
      return CheckRequirementResult::Success;
    subReqs.append(condReqs.begin(), condReqs.end());
    return CheckRequirementResult::ConditionalConformance;
  }

  case RequirementKind::Layout: {
    if (auto packType = firstType->getAs<PackType>()) {
      return expandPackRequirement(packType);
    }

    if (auto *archetypeType = firstType->getAs<ArchetypeType>()) {
      auto layout = archetypeType->getLayoutConstraint();
      if (layout && layout.merge(getLayoutConstraint()))
        return CheckRequirementResult::Success;

      return CheckRequirementResult::RequirementFailure;
    }

    if (getLayoutConstraint()->isClass()) {
      if (firstType->satisfiesClassConstraint())
        return CheckRequirementResult::Success;

      return CheckRequirementResult::RequirementFailure;
    }

    // TODO: Statically check other layout constraints, once they can
    // be spelled in Swift.
    return CheckRequirementResult::Success;
  }

  case RequirementKind::Superclass:
    if (auto packType = firstType->getAs<PackType>()) {
      return expandPackRequirement(packType);
    }

    if (getSecondType()->isExactSuperclassOf(firstType))
      return CheckRequirementResult::Success;

    return CheckRequirementResult::RequirementFailure;

  case RequirementKind::SameType:
    if (firstType->isEqual(getSecondType()))
      return CheckRequirementResult::Success;

    return CheckRequirementResult::RequirementFailure;

  case RequirementKind::SameShape:
    if (firstType->getReducedShape() ==
        getSecondType()->getReducedShape())
      return CheckRequirementResult::Success;

    return CheckRequirementResult::RequirementFailure;
  }

  llvm_unreachable("Bad requirement kind");
}

bool Requirement::canBeSatisfied() const {
  switch (getKind()) {
  case RequirementKind::SameShape:
    llvm_unreachable("Same-shape requirements not supported here");

  case RequirementKind::Conformance:
    return getFirstType()->is<ArchetypeType>();

  case RequirementKind::Layout: {
    if (auto *archetypeType = getFirstType()->getAs<ArchetypeType>()) {
      auto layout = archetypeType->getLayoutConstraint();
      return (!layout || layout.merge(getLayoutConstraint()));
    }

    return false;
  }

  case RequirementKind::Superclass:
    return (getFirstType()->isBindableTo(getSecondType()) ||
            getSecondType()->isBindableTo(getFirstType()));

  case RequirementKind::SameType:
    return (getFirstType()->isBindableTo(getSecondType()) ||
            getSecondType()->isBindableTo(getFirstType()));
  }

  llvm_unreachable("Bad requirement kind");
}

/// Determine the canonical ordering of requirements.
static unsigned getRequirementKindOrder(RequirementKind kind) {
  switch (kind) {
  case RequirementKind::SameShape: return 4;
  case RequirementKind::Conformance: return 2;
  case RequirementKind::Superclass: return 0;
  case RequirementKind::SameType: return 3;
  case RequirementKind::Layout: return 1;
  }
  llvm_unreachable("unhandled kind");
}

/// Linear order on requirements in a generic signature.
int Requirement::compare(const Requirement &other) const {
  int compareLHS =
    compareDependentTypes(getFirstType(), other.getFirstType());

  if (compareLHS != 0)
    return compareLHS;

  int compareKind = (getRequirementKindOrder(getKind()) -
                     getRequirementKindOrder(other.getKind()));

  if (compareKind != 0)
    return compareKind;

  // We should only have multiple conformance requirements.
  if (getKind() != RequirementKind::Conformance) {
    llvm::errs() << "Unordered generic requirements\n";
    llvm::errs() << "LHS: "; dump(llvm::errs()); llvm::errs() << "\n";
    llvm::errs() << "RHS: "; other.dump(llvm::errs()); llvm::errs() << "\n";
    abort();
  }

  int compareProtos =
    TypeDecl::compare(getProtocolDecl(), other.getProtocolDecl());
  assert(compareProtos != 0 && "Duplicate conformance requirements");

  return compareProtos;
}