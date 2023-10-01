//===--- CachingUtils.h -----------------------------------------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_FRONTEND_CACHINGUTILS_H
#define SWIFT_FRONTEND_CACHINGUTILS_H

#include "swift/Frontend/CachedDiagnostics.h"
#include "swift/Frontend/FrontendInputsAndOutputs.h"
#include "clang/CAS/CASOptions.h"
#include "llvm/ADT/IntrusiveRefCntPtr.h"
#include "llvm/CAS/ActionCache.h"
#include "llvm/CAS/CASReference.h"
#include "llvm/CAS/ObjectStore.h"
#include "llvm/Support/VirtualFileSystem.h"
#include "llvm/Support/VirtualOutputBackend.h"
#include <memory>

namespace swift {

/// Create a swift caching output backend that stores the output from
/// compiler into a CAS.
llvm::IntrusiveRefCntPtr<llvm::vfs::OutputBackend>
createSwiftCachingOutputBackend(
    llvm::cas::ObjectStore &CAS, llvm::cas::ActionCache &Cache,
    llvm::cas::ObjectRef BaseKey,
    const FrontendInputsAndOutputs &InputsAndOutputs);

/// Replay the output of the compilation from cache.
/// Return true if outputs are replayed, false otherwise.
bool replayCachedCompilerOutputs(
    llvm::cas::ObjectStore &CAS, llvm::cas::ActionCache &Cache,
    llvm::cas::ObjectRef BaseKey, DiagnosticEngine &Diag,
    const FrontendInputsAndOutputs &InputsAndOutputs,
    CachingDiagnosticsProcessor &CDP, bool CacheRemarks);

/// Load the cached compile result from cache.
std::unique_ptr<llvm::MemoryBuffer> loadCachedCompileResultFromCacheKey(
    llvm::cas::ObjectStore &CAS, llvm::cas::ActionCache &Cache,
    DiagnosticEngine &Diag, llvm::StringRef CacheKey,
    llvm::StringRef Filename = "");

/// Store compiler output.
llvm::Error storeCachedCompilerOutput(llvm::cas::ObjectStore &CAS,
                                      llvm::cas::ActionCache &Cache,
                                      StringRef Path, StringRef Bytes,
                                      llvm::cas::ObjectRef BaseKey,
                                      StringRef CorrespondingInput,
                                      file_types::ID OutputKind);

llvm::Expected<llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem>>
createCASFileSystem(llvm::cas::ObjectStore &CAS, ArrayRef<std::string> FSRoots,
                    ArrayRef<std::string> IncludeTreeRoots);
}

#endif
