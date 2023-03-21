//===--- MoveOnlyAddressCheckerUtils.h ------------------------------------===//
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

#ifndef SWIFT_SILOPTIMIZER_MANDATORY_MOVEONLYADDRESSCHECKERUTILS_H
#define SWIFT_SILOPTIMIZER_MANDATORY_MOVEONLYADDRESSCHECKERUTILS_H

#include "MoveOnlyBorrowToDestructureUtils.h"

namespace swift {

namespace siloptimizer {

class DiagnosticEmitter;

/// Searches for candidate mark must checks.
///
/// NOTE: To see if we emitted a diagnostic, use \p
/// diagnosticEmitter.getDiagnosticCount().
void searchForCandidateAddressMarkMustChecks(
    SILFunction *fn,
    SmallSetVector<MarkMustCheckInst *, 32> &moveIntroducersToProcess,
    DiagnosticEmitter &diagnosticEmitter);

struct MoveOnlyAddressChecker {
  SILFunction *fn;
  DiagnosticEmitter &diagnosticEmitter;
  borrowtodestructure::IntervalMapAllocator &allocator;
  DominanceInfo *domTree;
  PostOrderAnalysis *poa;

  /// \returns true if we changed the IR. To see if we emitted a diagnostic, use
  /// \p diagnosticEmitter.getDiagnosticCount().
  bool check(SmallSetVector<MarkMustCheckInst *, 32> &moveIntroducersToProcess);
};

} // namespace siloptimizer

} // namespace swift

#endif
