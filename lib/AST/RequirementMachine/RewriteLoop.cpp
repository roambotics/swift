//===--- RewriteLoop.cpp - Identities between rewrite rules ---------------===//
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

#include "swift/AST/Type.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include "RewriteSystem.h"

using namespace swift;
using namespace rewriting;

/// Dumps the rewrite step that was applied to \p term. Mutates \p term to
/// reflect the application of the rule.
void RewriteStep::dump(llvm::raw_ostream &out,
                       RewritePathEvaluator &evaluator,
                       const RewriteSystem &system) const {
  switch (Kind) {
  case ApplyRewriteRule: {
    auto result = evaluator.applyRewriteRule(*this, system);

    if (!result.prefix.empty()) {
      out << result.prefix;
      out << ".";
    }
    out << "(" << result.lhs << " => " << result.rhs << ")";
    if (!result.suffix.empty()) {
      out << ".";
      out << result.suffix;
    }

    break;
  }
  case AdjustConcreteType: {
    auto pair = evaluator.applyAdjustment(*this, system);

    out << "(σ";
    out << (Inverse ? " - " : " + ");
    out << pair.first << ")";

    if (!pair.second.empty())
      out << "." << pair.second;

    break;
  }
  case Shift: {
    evaluator.applyShift(*this, system);

    out << (Inverse ? "B>A" : "A>B");
    break;
  }
  case Decompose: {
    evaluator.applyDecompose(*this, system);

    out << (Inverse ? "Compose(" : "Decompose(");
    out << Arg << ")";
    break;
  }
  case Relation: {
    evaluator.applyRelation(*this, system);

    auto relation = system.getRelation(Arg);
    out << "Relation(";
    if (Inverse) {
      out << relation.second << " > " << relation.first;
    } else {
      out << relation.first << " < " << relation.second;
    }
    out << ")";
    break;
  }
  case ConcreteConformance: {
    evaluator.applyConcreteConformance(*this, system);

    out << (Inverse ? "ConcreteConformance⁻¹"
                    : "ConcreteConformance");
    break;
  }
  case SuperclassConformance: {
    evaluator.applyConcreteConformance(*this, system);

    out << (Inverse ? "SuperclassConformance⁻¹"
                    : "SuperclassConformance");
    break;
  }
  case ConcreteTypeWitness: {
    evaluator.applyConcreteTypeWitness(*this, system);

    out << (Inverse ? "ConcreteTypeWitness⁻¹"
                    : "ConcreteTypeWitness");
    break;
  }
  case SameTypeWitness: {
    evaluator.applySameTypeWitness(*this, system);

    out << (Inverse ? "SameTypeWitness⁻¹"
                    : "SameTypeWitness");
    break;
  }
  case AbstractTypeWitness: {
    evaluator.applyAbstractTypeWitness(*this, system);

    out << (Inverse ? "AbstractTypeWitness⁻¹"
                    : "AbstractTypeWitness");
    break;
  }

  }
}

/// Invert a rewrite path, producing a path that rewrites the original path's
/// destination back to the original path's source.
void RewritePath::invert() {
  std::reverse(Steps.begin(), Steps.end());

  for (auto &step : Steps)
    step.invert();
}

/// Dumps a series of rewrite steps applied to \p term.
void RewritePath::dump(llvm::raw_ostream &out,
                       MutableTerm term,
                       const RewriteSystem &system) const {
  RewritePathEvaluator evaluator(term);
  bool first = true;

  for (const auto &step : Steps) {
    if (!first) {
      out << " ⊗ ";
    } else {
      first = false;
    }

    step.dump(out, evaluator, system);
  }
}

void RewriteLoop::dump(llvm::raw_ostream &out,
                       const RewriteSystem &system) const {
  out << Basepoint << ": ";
  Path.dump(out, Basepoint, system);
  if (isDeleted())
    out << " [deleted]";
}

void RewritePathEvaluator::dump(llvm::raw_ostream &out) const {
  out << "Primary stack:\n";
  for (const auto &term : Primary) {
    out << term << "\n";
  }
  out << "\nSecondary stack:\n";
  for (const auto &term : Secondary) {
    out << term << "\n";
  }
}

void RewritePathEvaluator::checkPrimary() const {
  if (Primary.empty()) {
    llvm::errs() << "Empty primary stack\n";
    dump(llvm::errs());
    abort();
  }
}

void RewritePathEvaluator::checkSecondary() const {
  if (Secondary.empty()) {
    llvm::errs() << "Empty secondary stack\n";
    dump(llvm::errs());
    abort();
  }
}

MutableTerm &RewritePathEvaluator::getCurrentTerm() {
  checkPrimary();
  return Primary.back();
}

AppliedRewriteStep
RewritePathEvaluator::applyRewriteRule(const RewriteStep &step,
                                       const RewriteSystem &system) {
  auto &term = getCurrentTerm();

  assert(step.Kind == RewriteStep::ApplyRewriteRule);

  const auto &rule = system.getRule(step.getRuleID());

  auto lhs = (step.Inverse ? rule.getRHS() : rule.getLHS());
  auto rhs = (step.Inverse ? rule.getLHS() : rule.getRHS());

  auto bug = [&](StringRef msg) {
    llvm::errs() << msg << "\n";
    llvm::errs() << "- Term: " << term << "\n";
    llvm::errs() << "- StartOffset: " << step.StartOffset << "\n";
    llvm::errs() << "- EndOffset: " << step.EndOffset << "\n";
    llvm::errs() << "- Expected subterm: " << lhs << "\n";
    abort();
  };

  if (term.size() != step.StartOffset + lhs.size() + step.EndOffset) {
    bug("Invalid whiskering");
  }

  if (!std::equal(term.begin() + step.StartOffset,
                  term.begin() + step.StartOffset + lhs.size(),
                  lhs.begin())) {
    bug("Invalid subterm");
  }

  MutableTerm prefix(term.begin(), term.begin() + step.StartOffset);
  MutableTerm suffix(term.end() - step.EndOffset, term.end());

  term = prefix;
  term.append(rhs);
  term.append(suffix);

  return {lhs, rhs, prefix, suffix};
}

std::pair<MutableTerm, MutableTerm>
RewritePathEvaluator::applyAdjustment(const RewriteStep &step,
                                      const RewriteSystem &system) {
  auto &term = getCurrentTerm();

  assert(step.Kind == RewriteStep::AdjustConcreteType);

  auto &ctx = system.getRewriteContext();
  MutableTerm prefix(term.begin() + step.StartOffset,
                     term.begin() + step.StartOffset + step.Arg);
  MutableTerm suffix(term.end() - step.EndOffset - 1, term.end());

  // We're either adding or removing the prefix to each concrete substitution.
  Symbol &last = *(term.end() - step.EndOffset - 1);
  if (!last.hasSubstitutions()) {
    llvm::errs() << "Invalid rewrite path\n";
    llvm::errs() << "- Term: " << term << "\n";
    llvm::errs() << "- Start offset: " << step.StartOffset << "\n";
    llvm::errs() << "- End offset: " << step.EndOffset << "\n";
    abort();
  }

  last = last.transformConcreteSubstitutions(
    [&](Term t) -> Term {
      if (step.Inverse) {
        if (!std::equal(t.begin(),
                        t.begin() + step.Arg,
                        prefix.begin())) {
          llvm::errs() << "Invalid rewrite path\n";
          llvm::errs() << "- Term: " << term << "\n";
          llvm::errs() << "- Substitution: " << t << "\n";
          llvm::errs() << "- Start offset: " << step.StartOffset << "\n";
          llvm::errs() << "- End offset: " << step.EndOffset << "\n";
          llvm::errs() << "- Expected subterm: " << prefix << "\n";
          abort();
        }

        MutableTerm mutTerm(t.begin() + step.Arg, t.end());
        return Term::get(mutTerm, ctx);
      } else {
        MutableTerm mutTerm(prefix);
        mutTerm.append(t);
        return Term::get(mutTerm, ctx);
      }
    }, ctx);

  return std::make_pair(prefix, suffix);
}

void RewritePathEvaluator::applyShift(const RewriteStep &step,
                                      const RewriteSystem &system) {
  assert(step.Kind == RewriteStep::Shift);
  assert(step.StartOffset == 0);
  assert(step.EndOffset == 0);
  assert(step.Arg == 0);

  if (!step.Inverse) {
    // Move top of primary stack to secondary stack.
    checkPrimary();
    Secondary.push_back(Primary.back());
    Primary.pop_back();
  } else {
    // Move top of secondary stack to primary stack.
    checkSecondary();
    Primary.push_back(Secondary.back());
    Secondary.pop_back();
  }
}

void RewritePathEvaluator::applyRelation(const RewriteStep &step,
                                         const RewriteSystem &system) {
  assert(step.Kind == RewriteStep::Relation);

  auto relation = system.getRelation(step.Arg);
  auto &term = getCurrentTerm();

  if (!step.Inverse) {
    // Given a term T.[p1].[p2].U where |U| == EndOffset, build the
    // term T.[p1].U.

    auto lhsProperty = *(term.end() - step.EndOffset - 2);
    auto rhsProperty = *(term.end() - step.EndOffset - 1);
    assert(lhsProperty == relation.first);
    assert(rhsProperty == relation.second);

    MutableTerm result(term.begin(), term.end() - step.EndOffset - 1);
    result.append(term.end() - step.EndOffset, term.end());

    term = result;
  } else {
    // Given a term T.[p1].U where |U| == EndOffset, build the
    // term T.[p1].[p2].U.

    auto lhsProperty = *(term.end() - step.EndOffset - 1);
    assert(lhsProperty == relation.first);

    MutableTerm result(term.begin(), term.end() - step.EndOffset);
    result.add(relation.second);
    result.append(term.end() - step.EndOffset, term.end());

    term = result;
  }
}

void RewritePathEvaluator::applyDecompose(const RewriteStep &step,
                                          const RewriteSystem &system) {
  assert(step.Kind == RewriteStep::Decompose);

  auto &ctx = system.getRewriteContext();
  unsigned numSubstitutions = step.Arg;

  if (!step.Inverse) {
    // The input term takes the form U.[concrete: C].V or U.[superclass: C].V,
    // where |V| == EndOffset.
    const auto &term = getCurrentTerm();
    auto symbol = *(term.end() - step.EndOffset - 1);
    if (!symbol.hasSubstitutions()) {
      llvm::errs() << "Expected term with superclass or concrete type symbol"
                   << " on primary stack\n";
      dump(llvm::errs());
      abort();
    }

    // The symbol must have the expected number of substitutions.
    if (symbol.getSubstitutions().size() != numSubstitutions) {
      llvm::errs() << "Expected " << numSubstitutions << " substitutions\n";
      dump(llvm::errs());
      abort();
    }

    // Push each substitution on the primary stack.
    for (auto substitution : symbol.getSubstitutions()) {
      Primary.push_back(MutableTerm(substitution));
    }
  } else {
    // The primary stack must store the number of substitutions, together with
    // a term that takes the form U.[concrete: C].V or U.[superclass: C].V,
    // where |V| == EndOffset.
    if (Primary.size() < numSubstitutions + 1) {
      llvm::errs() << "Not enough terms on primary stack\n";
      dump(llvm::errs());
      abort();
    }

    // The term immediately underneath the substitutions is the one we're
    // updating with new substitutions.
    auto &term = *(Primary.end() - numSubstitutions - 1);

    auto &symbol = *(term.end() - step.EndOffset - 1);
    if (!symbol.hasSubstitutions()) {
      llvm::errs() << "Expected term with superclass or concrete type symbol"
                   << " on primary stack\n";
      dump(llvm::errs());
      abort();
    }

    // The symbol at the end of this term must have the expected number of
    // substitutions.
    if (symbol.getSubstitutions().size() != numSubstitutions) {
      llvm::errs() << "Expected " << numSubstitutions << " substitutions\n";
      dump(llvm::errs());
      abort();
    }

    // Collect the substitutions from the primary stack.
    SmallVector<Term, 2> substitutions;
    substitutions.reserve(numSubstitutions);
    for (unsigned i = 0; i < numSubstitutions; ++i) {
      const auto &substitution = *(Primary.end() - numSubstitutions + i);
      substitutions.push_back(Term::get(substitution, ctx));
    }

    // Build the new symbol with the new substitutions.
    symbol = symbol.withConcreteSubstitutions(substitutions, ctx);

    // Pop the substitutions from the primary stack.
    Primary.resize(Primary.size() - numSubstitutions);
  }
}

void
RewritePathEvaluator::applyConcreteConformance(const RewriteStep &step,
                                               const RewriteSystem &system) {
  checkPrimary();
  auto &term = Primary.back();
  Symbol *last = term.end() - step.EndOffset;

  auto &ctx = system.getRewriteContext();

  if (!step.Inverse) {
    // The input term takes one of the following forms, where |V| == EndOffset:
    // - U.[concrete: C].[P].V
    // - U.[superclass: C].[P].V
    assert(term.size() > step.EndOffset + 2);
    auto concreteType = *(last - 2);
    auto proto = *(last - 1);
    assert(proto.getKind() == Symbol::Kind::Protocol);

    // Get the prefix U.
    MutableTerm newTerm(term.begin(), last - 2);

    // Build the term U.[concrete: C : P].
    if (step.Kind == RewriteStep::ConcreteConformance) {
      assert(concreteType.getKind() == Symbol::Kind::ConcreteType);

      newTerm.add(Symbol::forConcreteConformance(
          concreteType.getConcreteType(),
          concreteType.getSubstitutions(),
          proto.getProtocol(),
          ctx));
    } else {
      assert(step.Kind == RewriteStep::SuperclassConformance);
      assert(concreteType.getKind() == Symbol::Kind::Superclass);

      newTerm.add(Symbol::forConcreteConformance(
          concreteType.getSuperclass(),
          concreteType.getSubstitutions(),
          proto.getProtocol(),
          ctx));
    }

    // Add the suffix V to get the final term U.[concrete: C : P].V.
    newTerm.append(last, term.end());
    term = newTerm;
  } else {
    // The input term takes the form U.[concrete: C : P].V, where
    // |V| == EndOffset.
    assert(term.size() > step.EndOffset + 1);
    auto concreteConformance = *(last - 1);
    assert(concreteConformance.getKind() == Symbol::Kind::ConcreteConformance);

    // Build the term U.
    MutableTerm newTerm(term.begin(), last - 1);

    // Add the symbol [concrete: C] or [superclass: C] to get the term
    // U.[concrete: C] or U.[superclass: C].
    if (step.Kind == RewriteStep::ConcreteConformance) {
      newTerm.add(Symbol::forConcreteType(
          concreteConformance.getConcreteType(),
          concreteConformance.getSubstitutions(),
          ctx));
    } else {
      assert(step.Kind == RewriteStep::SuperclassConformance);
      newTerm.add(Symbol::forSuperclass(
          concreteConformance.getConcreteType(),
          concreteConformance.getSubstitutions(),
          ctx));
    }

    // Add the symbol [P] to get the term U.[concrete: C].[P] or
    // U.[superclass: C].[P].
    newTerm.add(Symbol::forProtocol(
        concreteConformance.getProtocol(),
        ctx));

    // Add the suffix V to get the final term U.[concrete: C].[P].V or
    // U.[superclass: C].[P].V.
    newTerm.append(last, term.end());
    term = newTerm;
  }
}

void RewritePathEvaluator::applyConcreteTypeWitness(const RewriteStep &step,
                                                  const RewriteSystem &system) {
  checkPrimary();
  auto &term = Primary.back();

  const auto &witness = system.getTypeWitness(step.Arg);
  auto fail = [&]() {
    llvm::errs() << "Bad concrete type witness term:\n";
    llvm::errs() << term << "\n\n";
    witness.dump(llvm::errs());
    llvm::errs() << "End offset: " << step.EndOffset << "\n";
    llvm::errs() << "Inverse: " << step.Inverse << "\n";
    abort();
  };

  if (!step.Inverse) {
    // Make sure the term takes the following form, where |V| == EndOffset:
    //
    //    U.[concrete: C : P].[P:X].[concrete: C.X].V
    if (term.size() <= step.EndOffset + 3 ||
        *(term.end() - step.EndOffset - 3) != witness.getConcreteConformance() ||
        *(term.end() - step.EndOffset - 2) != witness.getAssocType() ||
        *(term.end() - step.EndOffset - 1) != witness.getConcreteType()) {
      fail();
    }

    // Get the subterm U.[concrete: C : P].[P:X].
    MutableTerm newTerm(term.begin(), term.end() - step.EndOffset - 1);

    // Add the subterm V, to get U.[concrete: C : P].[P:X].V.
    newTerm.append(term.end() - step.EndOffset, term.end());

    term = newTerm;
  } else {
    // Make sure the term takes the following form, where |V| == EndOffset:
    //
    //    U.[concrete: C : P].[P:X].V
    if (term.size() <= step.EndOffset + 2 ||
        *(term.end() - step.EndOffset - 2) != witness.getConcreteConformance() ||
        *(term.end() - step.EndOffset - 1) != witness.getAssocType()) {
      fail();
    }

    // Get the subterm U.[concrete: C : P].[P:X].
    MutableTerm newTerm(term.begin(), term.end() - step.EndOffset);

    // Add the symbol [concrete: C.X].
    newTerm.add(witness.getConcreteType());

    // Add the subterm V, to get
    //
    //    U.[concrete: C : P].[P:X].[concrete: C.X].V
    newTerm.append(term.end() - step.EndOffset, term.end());

    term = newTerm;
  }
}

void RewritePathEvaluator::applySameTypeWitness(const RewriteStep &step,
                                                const RewriteSystem &system) {
  checkPrimary();
  auto &term = Primary.back();

  const auto &witness = system.getTypeWitness(step.Arg);
  auto fail = [&]() {
    llvm::errs() << "Bad same-type witness term:\n";
    llvm::errs() << term << "\n\n";
    witness.dump(llvm::errs());
    abort();
  };

  auto concreteConformanceSymbol = witness.getConcreteConformance();

#ifndef NDEBUG
  if (witness.getConcreteType().getConcreteType() !=
      concreteConformanceSymbol.getConcreteType()) {
    fail();
  }
#endif

  auto witnessConcreteType = Symbol::forConcreteType(
      concreteConformanceSymbol.getConcreteType(),
      concreteConformanceSymbol.getSubstitutions(),
      system.getRewriteContext());

  if (!step.Inverse) {
    // Make sure the term takes the following form, where |V| == EndOffset:
    //
    //    U.[concrete: C : P].[P:X].[concrete: C].V
    if (term.size() <= step.EndOffset + 3 ||
        *(term.end() - step.EndOffset - 3) != concreteConformanceSymbol ||
        *(term.end() - step.EndOffset - 2) != witness.getAssocType() ||
        *(term.end() - step.EndOffset - 1) != witnessConcreteType) {
      fail();
    }

    // Get the subterm U.[concrete: C : P].
    MutableTerm newTerm(term.begin(), term.end() - step.EndOffset - 2);

    // Add the subterm V, to get U.[concrete: C : P].V.
    newTerm.append(term.end() - step.EndOffset, term.end());

    term = newTerm;
  } else {
    // Make sure the term takes the following form, where |V| == EndOffset:
    //
    //    U.[concrete: C : P].V
    if (term.size() <= step.EndOffset + 1 ||
        *(term.end() - step.EndOffset - 1) != concreteConformanceSymbol) {
      fail();
    }

    // Get the subterm U.[concrete: C : P].
    MutableTerm newTerm(term.begin(), term.end() - step.EndOffset);

    // Add the symbol [P:X].
    newTerm.add(witness.getAssocType());

    // Add the symbol [concrete: C].
    newTerm.add(witnessConcreteType);

    // Add the subterm V, to get
    //
    //    U.[concrete: C : P].[P:X].[concrete: C].V
    newTerm.append(term.end() - step.EndOffset, term.end());

    term = newTerm;
  }
}

void
RewritePathEvaluator::applyAbstractTypeWitness(const RewriteStep &step,
                                               const RewriteSystem &system) {
  checkPrimary();
  auto &term = Primary.back();

  const auto &witness = system.getTypeWitness(step.Arg);
  auto fail = [&]() {
    llvm::errs() << "Bad abstract type witness term:\n";
    llvm::errs() << term << "\n\n";
    witness.dump(llvm::errs());
    abort();
  };

  auto typeWitness = witness.getAbstractType();

  Term origTerm = (step.Inverse ? witness.LHS : typeWitness);
  Term substTerm = (step.Inverse ? typeWitness : witness.LHS);

  if (term.size() != step.StartOffset + origTerm.size() + step.EndOffset) {
    fail();
  }

  if (!std::equal(origTerm.begin(),
                  origTerm.end(),
                  term.begin() + step.StartOffset)) {
    fail();
  }

  MutableTerm newTerm(term.begin(), term.begin() + step.StartOffset);
  newTerm.append(substTerm);
  newTerm.append(term.end() - step.EndOffset, term.end());

  term = newTerm;
}

void RewritePathEvaluator::apply(const RewriteStep &step,
                                 const RewriteSystem &system) {
  switch (step.Kind) {
  case RewriteStep::ApplyRewriteRule:
    (void) applyRewriteRule(step, system);
    break;

  case RewriteStep::AdjustConcreteType:
    (void) applyAdjustment(step, system);
    break;

  case RewriteStep::Shift:
    applyShift(step, system);
    break;

  case RewriteStep::Decompose:
    applyDecompose(step, system);
    break;

  case RewriteStep::Relation:
    applyRelation(step, system);
    break;

  case RewriteStep::ConcreteConformance:
  case RewriteStep::SuperclassConformance:
    applyConcreteConformance(step, system);
    break;

  case RewriteStep::ConcreteTypeWitness:
    applyConcreteTypeWitness(step, system);
    break;

  case RewriteStep::SameTypeWitness:
    applySameTypeWitness(step, system);
    break;

  case RewriteStep::AbstractTypeWitness:
    applyAbstractTypeWitness(step, system);
    break;
  }
}
