//===--- ModuleDependencyScanner.cpp - Compute module dependencies --------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/AST/ASTContext.h"
#include "swift/AST/DiagnosticEngine.h"
#include "swift/AST/DiagnosticSuppression.h"
#include "swift/AST/DiagnosticsFrontend.h"
#include "swift/AST/DiagnosticsSema.h"
#include "swift/AST/ModuleDependencies.h"
#include "swift/AST/ModuleLoader.h"
#include "swift/AST/SourceFile.h"
#include "swift/AST/TypeCheckRequests.h"
#include "swift/Basic/FileTypes.h"
#include "swift/Basic/PrettyStackTrace.h"
#include "swift/DependencyScan/ModuleDependencyScanner.h"
#include "swift/Frontend/ModuleInterfaceLoader.h"
#include "swift/Serialization/SerializedModuleLoader.h"
#include "swift/Subsystems.h"
#include "llvm/ADT/IntrusiveRefCntPtr.h"
#include "llvm/ADT/SetOperations.h"
#include "llvm/CAS/CachingOnDiskFileSystem.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/Threading.h"
#include "llvm/Support/VirtualFileSystem.h"
#include <algorithm>

using namespace swift;

static void findPath_dfs(ModuleDependencyID X, ModuleDependencyID Y,
                         ModuleDependencyIDSet &visited,
                         std::vector<ModuleDependencyID> &stack,
                         std::vector<ModuleDependencyID> &result,
                         const ModuleDependenciesCache &cache) {
  stack.push_back(X);
  if (X == Y) {
    copy(stack.begin(), stack.end(), std::back_inserter(result));
    return;
  }
  visited.insert(X);
  auto optionalNode = cache.findDependency(X);
  auto node = optionalNode.value();
  assert(optionalNode.has_value() && "Expected cache value for dependency.");
  for (const auto &dep : node->getModuleImports()) {
    llvm::Optional<ModuleDependencyKind> lookupKind = llvm::None;
    // Underlying Clang module needs an explicit lookup to avoid confusing it
    // with the parent Swift module.
    if ((dep == X.ModuleName && node->isSwiftModule()) || node->isClangModule())
      lookupKind = ModuleDependencyKind::Clang;

    auto optionalDepNode = cache.findDependency(dep, lookupKind);
    if (!optionalDepNode.has_value())
      continue;
    auto depNode = optionalDepNode.value();
    auto depID = ModuleDependencyID{dep, depNode->getKind()};
    if (!visited.count(depID)) {
      findPath_dfs(depID, Y, visited, stack, result, cache);
    }
  }
  stack.pop_back();
}

static std::vector<ModuleDependencyID>
findPathToDependency(ModuleDependencyID dependency,
                     const ModuleDependenciesCache &cache) {
  auto mainModuleDep = cache.findDependency(cache.getMainModuleName(),
                                            ModuleDependencyKind::SwiftSource);
  // We may be in a batch scan instance which does not have this dependency
  if (!mainModuleDep.has_value())
    return {};
  auto mainModuleID = ModuleDependencyID{cache.getMainModuleName().str(),
                                         ModuleDependencyKind::SwiftSource};
  auto visited = ModuleDependencyIDSet();
  auto stack = std::vector<ModuleDependencyID>();
  auto dependencyPath = std::vector<ModuleDependencyID>();
  findPath_dfs(mainModuleID, dependency, visited, stack, dependencyPath, cache);
  return dependencyPath;
}

// Diagnose scanner failure and attempt to reconstruct the dependency
// path from the main module to the missing dependency.
static void
diagnoseScannerFailure(StringRef moduleName, DiagnosticEngine &Diags,
                       const ModuleDependenciesCache &cache,
                       llvm::Optional<ModuleDependencyID> dependencyOf) {
  Diags.diagnose(SourceLoc(), diag::dependency_scan_module_not_found,
                 moduleName);
  if (dependencyOf.has_value()) {
    auto path = findPathToDependency(dependencyOf.value(), cache);
    // We may fail to construct a path in some cases, such as a Swift overlay of
    // a Clang module dependnecy.
    if (path.empty())
      path = {dependencyOf.value()};

    for (auto it = path.rbegin(), end = path.rend(); it != end; ++it) {
      const auto &entry = *it;
      auto optionalEntryNode = cache.findDependency(entry);
      assert(optionalEntryNode.has_value());
      auto entryNode = optionalEntryNode.value();
      std::string moduleFilePath = "";
      bool isClang = false;
      switch (entryNode->getKind()) {
      case swift::ModuleDependencyKind::SwiftSource:
        Diags.diagnose(SourceLoc(), diag::dependency_as_imported_by_main_module,
                       entry.ModuleName);
        continue;
      case swift::ModuleDependencyKind::SwiftInterface:
        moduleFilePath =
            entryNode->getAsSwiftInterfaceModule()->swiftInterfaceFile;
        break;
      case swift::ModuleDependencyKind::SwiftBinary:
        moduleFilePath =
            entryNode->getAsSwiftBinaryModule()->compiledModulePath;
        break;
      case swift::ModuleDependencyKind::SwiftPlaceholder:
        moduleFilePath =
            entryNode->getAsPlaceholderDependencyModule()->compiledModulePath;
        break;
      case swift::ModuleDependencyKind::Clang:
        moduleFilePath = entryNode->getAsClangModule()->moduleMapFile;
        isClang = true;
        break;
      default:
        llvm_unreachable("Unexpected dependency kind");
      }

      // TODO: Consider turning the module file (interface or modulemap) into
      // the SourceLoc of this diagnostic instead. Ideally with the location of
      // the `import` statement that this dependency originates from.
      Diags.diagnose(SourceLoc(), diag::dependency_as_imported_by,
                     entry.ModuleName, moduleFilePath, isClang);
    }
  }
}

ModuleDependencyScanningWorker::ModuleDependencyScanningWorker(
    SwiftDependencyScanningService &globalScanningService,
    const CompilerInvocation &ScanCompilerInvocation,
    const SILOptions &SILOptions, ASTContext &ScanASTContext,
    swift::DependencyTracker &DependencyTracker, DiagnosticEngine &Diagnostics)
    : // Diagnostics(Diagnostics),
      clangScanningTool(*globalScanningService.ClangScanningService,
                        globalScanningService.getClangScanningFS()) {
  // Configure the interface scanning AST delegate
  auto ClangModuleCachePath = getModuleCachePathFromClang(
      ScanASTContext.getClangModuleLoader()->getClangInstance());
  auto &FEOpts = ScanCompilerInvocation.getFrontendOptions();
  ModuleInterfaceLoaderOptions LoaderOpts(FEOpts);
  ScanningASTDelegate = std::make_unique<InterfaceSubContextDelegateImpl>(
      ScanASTContext.SourceMgr, &ScanASTContext.Diags,
      ScanASTContext.SearchPathOpts, ScanASTContext.LangOpts,
      ScanASTContext.ClangImporterOpts, LoaderOpts,
      /*buildModuleCacheDirIfAbsent*/ false, ClangModuleCachePath,
      FEOpts.PrebuiltModuleCachePath, FEOpts.BackupModuleInterfaceDir,
      FEOpts.SerializeModuleInterfaceDependencyHashes,
      FEOpts.shouldTrackSystemDependencies(), RequireOSSAModules_t(SILOptions));

  // Set up the Clang importer.
  clangScannerModuleLoader = ClangImporter::create(
      ScanASTContext, ScanCompilerInvocation.getPCHHash(), &DependencyTracker);
  if (!clangScannerModuleLoader)
    Diagnostics.diagnose(SourceLoc(), diag::error_clang_importer_create_fail);

  // Set up the Swift interface loader for Swift scanning.
  swiftScannerModuleLoader = ModuleInterfaceLoader::create(
      ScanASTContext,
      *static_cast<ModuleInterfaceCheckerImpl *>(
          ScanASTContext.getModuleInterfaceChecker()),
      &DependencyTracker, ModuleLoadingMode::OnlyInterface);
}

ModuleDependencyVector
ModuleDependencyScanningWorker::scanFilesystemForModuleDependency(
    StringRef moduleName, const ModuleDependenciesCache &cache,
    bool isTestableImport) {
  // First query a Swift module, otherwise lookup a Clang module
  ModuleDependencyVector moduleDependencies =
      swiftScannerModuleLoader->getModuleDependencies(
          moduleName, cache.getModuleOutputPath(),
          cache.getScanService().getCachingFS(),
          cache.getAlreadySeenClangModules(), clangScanningTool,
          *ScanningASTDelegate, isTestableImport);

  if (moduleDependencies.empty())
    moduleDependencies = clangScannerModuleLoader->getModuleDependencies(
        moduleName, cache.getModuleOutputPath(),
        cache.getScanService().getCachingFS(),
        cache.getAlreadySeenClangModules(), clangScanningTool,
        *ScanningASTDelegate, isTestableImport);

  return moduleDependencies;
}

ModuleDependencyVector
ModuleDependencyScanningWorker::scanFilesystemForSwiftModuleDependency(
    StringRef moduleName, const ModuleDependenciesCache &cache) {
  return swiftScannerModuleLoader->getModuleDependencies(
      moduleName, cache.getModuleOutputPath(),
      cache.getScanService().getCachingFS(), cache.getAlreadySeenClangModules(),
      clangScanningTool, *ScanningASTDelegate, false);
}

ModuleDependencyVector
ModuleDependencyScanningWorker::scanFilesystemForClangModuleDependency(
    StringRef moduleName, const ModuleDependenciesCache &cache) {
  return clangScannerModuleLoader->getModuleDependencies(
      moduleName, cache.getModuleOutputPath(),
      cache.getScanService().getCachingFS(), cache.getAlreadySeenClangModules(),
      clangScanningTool, *ScanningASTDelegate, false);
}

template <typename Function, typename... Args>
auto ModuleDependencyScanner::withDependencyScanningWorker(Function &&F,
                                                           Args &&...ArgList) {
  auto getWorker = [this]() -> std::unique_ptr<ModuleDependencyScanningWorker> {
    std::lock_guard<std::mutex> guard(WorkersLock);
    // If we have run out of workers, something has gone wrong as we must never
    // have the number of workers exceeding the size of the thread pool
    // requesting them.
    if (Workers.empty())
      swift_unreachable("Out of Swift dependency scanning workers.");

    // Otherwise, return from the back.
    auto result = std::move(Workers.back());
    Workers.pop_back();
    return result;
  };

  auto releaseWorker =
      [this](std::unique_ptr<ModuleDependencyScanningWorker> &&worker) {
        std::lock_guard<std::mutex> guard(WorkersLock);
        Workers.emplace_front(std::move(worker));
      };

  std::unique_ptr<ModuleDependencyScanningWorker> worker = getWorker();
  auto Task = std::bind(std::forward<Function>(F), worker.get(),
                        std::forward<Args>(ArgList)...);
  auto result = Task();
  releaseWorker(std::move(worker));
  return result;
}

ModuleDependencyScanner::ModuleDependencyScanner(
    SwiftDependencyScanningService &ScanningService,
    const CompilerInvocation &ScanCompilerInvocation,
    const SILOptions &SILOptions, ASTContext &ScanASTContext,
    swift::DependencyTracker &DependencyTracker, DiagnosticEngine &Diagnostics,
    bool ParallelScan)
    : ScanCompilerInvocation(ScanCompilerInvocation),
      ScanASTContext(ScanASTContext), Diagnostics(Diagnostics),
      NumThreads(ParallelScan
                     ? llvm::hardware_concurrency().compute_thread_count()
                     : 1),
      ScanningThreadPool(llvm::hardware_concurrency(NumThreads)) {
  // TODO: Make num threads configurable
  for (size_t i = 0; i < NumThreads; ++i)
    Workers.emplace_front(std::make_unique<ModuleDependencyScanningWorker>(
        ScanningService, ScanCompilerInvocation, SILOptions, ScanASTContext,
        DependencyTracker, Diagnostics));
}

std::vector<ModuleDependencyID>
ModuleDependencyScanner::getModuleDependencies(ModuleDependencyID moduleID,
                                               ModuleDependenciesCache &cache) {
  ModuleDependencyIDSetVector allModules;
  allModules.insert(moduleID);
  for (unsigned currentModuleIdx = 0; currentModuleIdx < allModules.size();
       ++currentModuleIdx) {
    auto module = allModules[currentModuleIdx];
    auto discoveredModules = resolveDirectModuleDependencies(module, cache);

    // Do not need to resolve Clang modules, as they come fully-resolved
    // from the Clang dependency scanner.
    for (const auto &moduleID : discoveredModules)
      if (moduleID.Kind != ModuleDependencyKind::Clang)
        allModules.insert(moduleID);

    allModules.insert(discoveredModules.begin(), discoveredModules.end());
  }

  // Resolve cross-import overlays.
  discoverCrossImportOverlayDependencies(
      moduleID.ModuleName, allModules.getArrayRef().slice(1), cache,
      [&](ModuleDependencyID id) { allModules.insert(id); });

  return allModules.takeVector();
}

/// Find all of the imported Clang modules starting with the given module name.
static void findAllImportedClangModules(StringRef moduleName,
                                        ModuleDependenciesCache &cache,
                                        std::vector<std::string> &allModules,
                                        llvm::StringSet<> &knownModules) {
  if (!knownModules.insert(moduleName).second)
    return;
  allModules.push_back(moduleName.str());
  auto optionalDependencies =
      cache.findDependency(moduleName, ModuleDependencyKind::Clang);
  if (!optionalDependencies.has_value())
    return;

  auto dependencies = optionalDependencies.value();
  for (const auto &dep : dependencies->getDirectModuleDependencies())
    findAllImportedClangModules(dep.ModuleName, cache, allModules,
                                knownModules);
  for (const auto &dep : dependencies->getSwiftOverlayDependencies())
    findAllImportedClangModules(dep.ModuleName, cache, allModules,
                                knownModules);
}

llvm::ErrorOr<ModuleDependencyInfo>
ModuleDependencyScanner::getMainModuleDependencyInfo(
    ModuleDecl *mainModule, llvm::Optional<SwiftDependencyTracker> tracker) {
  // Main module file name.
  auto newExt = file_types::getExtension(file_types::TY_SwiftModuleFile);
  llvm::SmallString<32> mainModulePath = mainModule->getName().str();
  llvm::sys::path::replace_extension(mainModulePath, newExt);

  std::string apinotesVer = (llvm::Twine("-fapinotes-swift-version=") +
                             ScanASTContext.LangOpts.EffectiveLanguageVersion
                                 .asAPINotesVersionString())
                                .str();

  // Compute the dependencies of the main module.
  std::vector<StringRef> ExtraPCMArgs = {"-Xcc", apinotesVer};
  if (!ScanASTContext.LangOpts.ClangTarget.has_value())
    ExtraPCMArgs.insert(
        ExtraPCMArgs.begin(),
        {"-Xcc", "-target", "-Xcc", ScanASTContext.LangOpts.Target.str()});

  std::string rootID;
  if (tracker) {
    tracker->startTracking();
    for (auto fileUnit : mainModule->getFiles()) {
      auto sf = dyn_cast<SourceFile>(fileUnit);
      if (!sf)
        continue;
      tracker->trackFile(sf->getFilename());
    }
    tracker->addCommonSearchPathDeps(
        ScanCompilerInvocation.getSearchPathOptions());
    // Fetch some dependency files from clang importer.
    std::vector<std::string> clangDependencyFiles;
    auto clangImporter =
        static_cast<ClangImporter *>(ScanASTContext.getClangModuleLoader());
    clangImporter->addClangInvovcationDependencies(clangDependencyFiles);
    llvm::for_each(clangDependencyFiles,
                   [&](std::string &file) { tracker->trackFile(file); });

    auto root = tracker->createTreeFromDependencies();
    if (!root) {
      Diagnostics.diagnose(SourceLoc(), diag::error_cas,
                           toString(root.takeError()));
      return std::make_error_code(std::errc::io_error);
    }
    rootID = root->getID().toString();
  }

  auto mainDependencies =
      ModuleDependencyInfo::forSwiftSourceModule(rootID, {}, {}, ExtraPCMArgs);

  llvm::StringSet<> alreadyAddedModules;
  // Compute Implicit dependencies of the main module
  {
    const auto &importInfo = mainModule->getImplicitImportInfo();
    // Swift standard library.
    switch (importInfo.StdlibKind) {
    case ImplicitStdlibKind::None:
    case ImplicitStdlibKind::Builtin:
      break;

    case ImplicitStdlibKind::Stdlib:
      mainDependencies.addModuleImport("Swift", &alreadyAddedModules);
      break;
    }

    // Add any implicit module names.
    for (const auto &import : importInfo.AdditionalUnloadedImports) {
      mainDependencies.addModuleImport(import.module.getModulePath(),
                                       &alreadyAddedModules);
    }

    // Already-loaded, implicitly imported module names.
    for (const auto &import : importInfo.AdditionalImports) {
      mainDependencies.addModuleImport(
          import.module.importedModule->getNameStr(), &alreadyAddedModules);
    }

    // Add the bridging header.
    if (!importInfo.BridgingHeaderPath.empty()) {
      mainDependencies.addBridgingHeader(importInfo.BridgingHeaderPath);
    }

    // If we are to import the underlying Clang module of the same name,
    // add a dependency with the same name to trigger the search.
    if (importInfo.ShouldImportUnderlyingModule) {
      mainDependencies.addModuleImport(mainModule->getName().str(),
                                       &alreadyAddedModules);
    }

    // All modules specified with `-embed-tbd-for-module` are treated as
    // implicit dependnecies for this compilation since they are not guaranteed
    // to be impored in the source.
    for (const auto &tbdSymbolModule :
         ScanCompilerInvocation.getTBDGenOptions().embedSymbolsFromModules) {
      mainDependencies.addModuleImport(tbdSymbolModule, &alreadyAddedModules);
    }
  }

  // Add source-specified `import` dependencies
  {
    for (auto fileUnit : mainModule->getFiles()) {
      auto sf = dyn_cast<SourceFile>(fileUnit);
      if (!sf)
	continue;

      mainDependencies.addModuleImport(*sf, alreadyAddedModules);
    }
  }    

  return mainDependencies;
}

/// Retrieve the module dependencies for the Clang module with the given name.
llvm::Optional<const ModuleDependencyInfo *>
ModuleDependencyScanner::getNamedClangModuleDependencyInfo(
    StringRef moduleName, ModuleDependenciesCache &cache) {
  // Check whether we've cached this result.
  if (auto found =
          cache.findDependency(moduleName, ModuleDependencyKind::Clang))
    return found;

  // Otherwise perform filesystem scan
  auto moduleDependencies = withDependencyScanningWorker(
      [&cache, moduleName](ModuleDependencyScanningWorker *ScanningWorker) {
        return ScanningWorker->scanFilesystemForClangModuleDependency(
            moduleName, cache);
      });
  if (moduleDependencies.empty())
    return llvm::None;

  cache.recordDependencies(moduleDependencies);
  return cache.findDependency(moduleDependencies[0].first);
}

/// Retrieve the module dependencies for the Swift module with the given name.
llvm::Optional<const ModuleDependencyInfo *>
ModuleDependencyScanner::getNamedSwiftModuleDependencyInfo(
    StringRef moduleName, ModuleDependenciesCache &cache) {
  // Check whether we've cached this result.
  if (auto found =
          cache.findDependency(moduleName, ModuleDependencyKind::SwiftSource))
    return found;
  if (auto found = cache.findDependency(moduleName,
                                        ModuleDependencyKind::SwiftInterface))
    return found;
  if (auto found =
          cache.findDependency(moduleName, ModuleDependencyKind::SwiftBinary))
    return found;
  if (auto found = cache.findDependency(moduleName,
                                        ModuleDependencyKind::SwiftPlaceholder))
    return found;

  // Otherwise perform filesystem scan
  auto moduleDependencies = withDependencyScanningWorker(
      [&cache, moduleName](ModuleDependencyScanningWorker *ScanningWorker) {
        return ScanningWorker->scanFilesystemForSwiftModuleDependency(
            moduleName, cache);
      });
  if (moduleDependencies.empty())
    return llvm::None;

  cache.recordDependencies(moduleDependencies);
  return cache.findDependency(moduleDependencies[0].first);
}

std::vector<ModuleDependencyID>
ModuleDependencyScanner::resolveDirectModuleDependencies(
    ModuleDependencyID moduleID, ModuleDependenciesCache &cache) {
  PrettyStackTraceStringAction trace("Resolving dependencies of: ",
                                     moduleID.ModuleName);
  auto optionalModuleDependencyInfo = cache.findDependency(moduleID);
  assert(optionalModuleDependencyInfo.has_value());
  auto moduleDependencyInfo = optionalModuleDependencyInfo.value();

  // If this dependency has already been resolved, return the result.
  if (moduleDependencyInfo->isResolved() &&
      moduleDependencyInfo->getKind() != ModuleDependencyKind::SwiftSource)
    return cache.getAllDependencies(moduleID);

  // Find the dependencies of every module this module directly depends on.
  ModuleDependencyIDSetVector directDependencies;
  ModuleDependencyIDSetVector swiftOverlayDependencies;
  resolveImportDependencies(moduleID, cache, directDependencies);

  // A record of all of the Clang modules referenced from this Swift module.
  std::vector<std::string> allClangModules;
  llvm::StringSet<> knownModules;
  // Find and add all bridging header dependencies.
  if (moduleDependencyInfo->isTextualSwiftModule())
    resolveBridgingHeaderDependencies(moduleID, cache, allClangModules,
                                      knownModules, directDependencies);

  // Find all of the discovered Clang modules that this module depends on.
  for (const auto &dep : directDependencies) {
    if (dep.Kind != ModuleDependencyKind::Clang)
      continue;
    findAllImportedClangModules(dep.ModuleName, cache, allClangModules,
                                knownModules);
  }

  // Find all Swift overlays that this module depends on.
  resolveSwiftOverlayDependencies(moduleID, allClangModules, cache,
                                  swiftOverlayDependencies, directDependencies);

  // Resolve the dependency info with dependency module information.
  cache.resolveDependencyImports(moduleID, directDependencies.getArrayRef());
  // Resolve the dependency info with Swift overlay dependency information.
  if (!swiftOverlayDependencies.empty())
    cache.setSwiftOverlayDependencues(moduleID,
                                      swiftOverlayDependencies.getArrayRef());

  ModuleDependencyIDSetVector result = directDependencies;
  result.insert(swiftOverlayDependencies.begin(),
                swiftOverlayDependencies.end());
  return result.takeVector();
}

void ModuleDependencyScanner::resolveImportDependencies(
    const ModuleDependencyID &moduleID, ModuleDependenciesCache &cache,
    ModuleDependencyIDSetVector &directDependencies) {
  auto optionalModuleDependencyInfo = cache.findDependency(moduleID);
  assert(optionalModuleDependencyInfo.has_value());
  auto moduleDependencyInfo = optionalModuleDependencyInfo.value();

  llvm::StringMap<llvm::Optional<ModuleDependencyVector>> moduleLookupResult;
  for (const auto &dependsOn : moduleDependencyInfo->getModuleImports())
    moduleLookupResult.insert(std::make_pair(dependsOn, llvm::None));

  // A scanning task to query a module by-name. If the module already exists
  // in the cache, do nothing and return.
  auto scanForModuleDependency = [this, &cache, &moduleLookupResult](
                                     StringRef moduleName, bool onlyClangModule,
                                     bool isTestable) {
    // If this is already in the cache, no work to do here
    if (onlyClangModule) {
      if (cache.hasDependency(moduleName, ModuleDependencyKind::Clang))
        return;
    } else {
      if (cache.hasDependency(moduleName))
        return;
    }

    auto moduleDependencies = withDependencyScanningWorker(
        [&cache, moduleName, onlyClangModule,
         isTestable](ModuleDependencyScanningWorker *ScanningWorker) {
          return onlyClangModule
                     ? ScanningWorker->scanFilesystemForClangModuleDependency(
                           moduleName, cache)
                     : ScanningWorker->scanFilesystemForModuleDependency(
                           moduleName, cache, isTestable);
        });
    moduleLookupResult.insert_or_assign(moduleName, moduleDependencies);
  };

  // Enque asynchronous lookup tasks
  for (const auto &dependsOn : moduleDependencyInfo->getModuleImports()) {
    bool underlyingClangModuleLookup = moduleID.ModuleName == dependsOn;
    bool isTestable = moduleDependencyInfo->isTestableImport(dependsOn);
    ScanningThreadPool.async(scanForModuleDependency, dependsOn,
                             underlyingClangModuleLookup, isTestable);
  }
  for (const auto &dependsOn :
       moduleDependencyInfo->getOptionalModuleImports()) {
    bool underlyingClangModuleLookup = moduleID.ModuleName == dependsOn;
    bool isTestable = moduleDependencyInfo->isTestableImport(dependsOn);
    ScanningThreadPool.async(scanForModuleDependency, dependsOn,
                             underlyingClangModuleLookup, isTestable);
  }
  ScanningThreadPool.wait();

  // Aggregate both previously-cached and freshly-scanned module results
  auto recordResolvedModuleImport =
      [this, &cache, &moduleLookupResult, &directDependencies,
       moduleID](const std::string &moduleName, bool optionalImport) {
        bool underlyingClangModule = moduleID.ModuleName == moduleName;
        auto lookupResult = moduleLookupResult[moduleName];
        // The imported module was found in the cache
        if (lookupResult == llvm::None) {
          const ModuleDependencyInfo *cachedInfo;
          if (underlyingClangModule)
            cachedInfo =
                cache.findDependency(moduleName, ModuleDependencyKind::Clang)
                    .value();
          else
            cachedInfo = cache.findDependency(moduleName).value();
          assert(cachedInfo && "Expected cached dependency info");
          directDependencies.insert({moduleName, cachedInfo->getKind()});
        } else {
          // Cache discovered module dependencies.
          cache.recordDependencies(lookupResult.value());
          if (!lookupResult.value().empty())
            directDependencies.insert(
                {moduleName, lookupResult.value()[0].first.Kind});
          else if (!optionalImport)
            diagnoseScannerFailure(moduleName, Diagnostics, cache, moduleID);
        }
      };
  for (const auto &dependsOn : moduleDependencyInfo->getModuleImports())
    recordResolvedModuleImport(dependsOn, false);
  for (const auto &optionallyDependsOn :
       moduleDependencyInfo->getOptionalModuleImports())
    recordResolvedModuleImport(optionallyDependsOn, true);
}

void ModuleDependencyScanner::resolveBridgingHeaderDependencies(
    const ModuleDependencyID &moduleID, ModuleDependenciesCache &cache,
    std::vector<std::string> &allClangModules,
    llvm::StringSet<> &alreadyKnownModules,
    ModuleDependencyIDSetVector &directDependencies) {
  auto optionalModuleDependencyInfo = cache.findDependency(moduleID);
  assert(optionalModuleDependencyInfo.has_value());
  auto moduleDependencyInfo = optionalModuleDependencyInfo.value();

  // If the Swift module has a bridging header, scan the header for dependencies
  // and add them to the module's direct dependencies.
  /// TODO: separate this out of here as well into a separate entry in
  /// `CommonSwiftTextualModuleDependencyDetails`
  if (moduleDependencyInfo->getBridgingHeader()) {
    withDependencyScanningWorker([&](ModuleDependencyScanningWorker
                                         *ScanningWorker) {
      auto clangImporter = static_cast<ClangImporter *>(
          ScanningWorker->clangScannerModuleLoader.get());

      if (!clangImporter->addBridgingHeaderDependencies(
              moduleID, ScanningWorker->clangScanningTool, cache)) {
        // Grab the updated module dependencies.
        // FIXME: This is such a hack.
        const ModuleDependencyInfo *updatedDependencyInfo =
            cache.findDependency(moduleID).value();

        // Add the Clang modules referenced from the bridging header to the
        // set of Clang modules we know about.
        const std::vector<std::string> *bridgingModuleDependencies = nullptr;
        if (auto swiftDeps = updatedDependencyInfo->getAsSwiftInterfaceModule())
          bridgingModuleDependencies =
              &(swiftDeps->textualModuleDetails.bridgingModuleDependencies);
        else if (auto sourceDeps =
                     updatedDependencyInfo->getAsSwiftSourceModule())
          bridgingModuleDependencies =
              &(sourceDeps->textualModuleDetails.bridgingModuleDependencies);

        assert(bridgingModuleDependencies);
        for (const auto &clangDep : *bridgingModuleDependencies) {
          directDependencies.insert({clangDep, ModuleDependencyKind::Clang});
          findAllImportedClangModules(clangDep, cache, allClangModules,
                                      alreadyKnownModules);
        }
      }
      return true;
    });
  }
}

void ModuleDependencyScanner::resolveSwiftOverlayDependencies(
    const ModuleDependencyID &moduleID,
    const std::vector<std::string> &clangDependencies,
    ModuleDependenciesCache &cache,
    ModuleDependencyIDSetVector &swiftOverlayDependencies,
    ModuleDependencyIDSetVector &directDependencies) {
  llvm::StringMap<llvm::Optional<ModuleDependencyVector>>
      swiftOverlayLookupResult;
  for (const auto &clangDep : clangDependencies)
    swiftOverlayLookupResult.insert(std::make_pair(clangDep, llvm::None));

  // A scanning task to query a Swift module by-name. If the module already
  // exists in the cache, do nothing and return.
  auto scanForSwiftDependency = [this, &cache, &swiftOverlayLookupResult](
                                    StringRef moduleName) {
    if (cache.hasDependency(moduleName, ModuleDependencyKind::SwiftInterface) ||
        cache.hasDependency(moduleName, ModuleDependencyKind::SwiftBinary) ||
        cache.hasDependency(moduleName, ModuleDependencyKind::SwiftPlaceholder))
      return;

    auto moduleDependencies = withDependencyScanningWorker(
        [&cache, moduleName](ModuleDependencyScanningWorker *ScanningWorker) {
          return ScanningWorker->scanFilesystemForModuleDependency(moduleName,
                                                                   cache);
        });
    swiftOverlayLookupResult.insert_or_assign(moduleName, moduleDependencies);
  };

  // Enque asynchronous lookup tasks
  for (const auto &clangDep : clangDependencies)
    ScanningThreadPool.async(scanForSwiftDependency, clangDep);
  ScanningThreadPool.wait();

  // Aggregate both previously-cached and freshly-scanned module results
  auto recordResult = [&cache, &swiftOverlayLookupResult,
                       &swiftOverlayDependencies,
                       &directDependencies,
                       moduleID](const std::string &moduleName) {
    auto lookupResult = swiftOverlayLookupResult[moduleName];
    if (moduleName != moduleID.ModuleName) {
      if (lookupResult == llvm::None) {
        const ModuleDependencyInfo *cachedInfo = cache.findDependency(moduleName).value();
        swiftOverlayDependencies.insert({moduleName, cachedInfo->getKind()});
        // FIXME: Once all clients know to fetch these dependencies from
        // `swiftOverlayDependencies`, the goal is to no longer have them in
        // `directDependencies` so the following will need to go away.
	directDependencies.insert({moduleName, cachedInfo->getKind()});
      } else {
        // Cache discovered module dependencies.
        cache.recordDependencies(lookupResult.value());
        if (!lookupResult.value().empty()) {
          swiftOverlayDependencies.insert(
                                          {moduleName, lookupResult.value()[0].first.Kind});
          // FIXME: Once all clients know to fetch these dependencies from
          // `swiftOverlayDependencies`, the goal is to no longer have them in
          // `directDependencies` so the following will need to go away.
	  directDependencies.insert(
                                    {moduleName, lookupResult.value()[0].first.Kind});
	}
      }
    }
  };
  for (const auto &clangDep : clangDependencies)
    recordResult(clangDep);
}

void ModuleDependencyScanner::discoverCrossImportOverlayDependencies(
    StringRef mainModuleName, ArrayRef<ModuleDependencyID> allDependencies,
    ModuleDependenciesCache &cache,
    llvm::function_ref<void(ModuleDependencyID)> action) {
  // Modules explicitly imported. Only these can be secondary module.
  llvm::SetVector<Identifier> newOverlays;
  for (auto dep : allDependencies) {
    auto moduleName = dep.ModuleName;
    // Do not look for overlays of main module under scan
    if (moduleName == mainModuleName)
      continue;

    auto dependencies = cache.findDependency(moduleName, dep.Kind).value();
    // Collect a map from secondary module name to cross-import overlay names.
    auto overlayMap = dependencies->collectCrossImportOverlayNames(
        ScanASTContext, moduleName);
    if (overlayMap.empty())
      continue;
    for (const auto &dependencyId : allDependencies) {
      auto moduleName = dependencyId.ModuleName;
      // Do not look for overlays of main module under scan
      if (moduleName == mainModuleName)
        return;
      // check if any explicitly imported modules can serve as a
      // secondary module, and add the overlay names to the
      // dependencies list.
      for (auto overlayName : overlayMap[moduleName]) {
        if (overlayName.str() != mainModuleName &&
            std::find_if(allDependencies.begin(), allDependencies.end(),
                         [&](ModuleDependencyID Id) {
                           return moduleName == overlayName.str();
                         }) == allDependencies.end()) {
          newOverlays.insert(overlayName);
        }
      }
    }
  }
  // No new cross-import overlays are found, return.
  if (newOverlays.empty())
    return;

  // Construct a dummy main to resolve the newly discovered cross import
  // overlays.
  StringRef dummyMainName = "DummyMainModuleForResolvingCrossImportOverlays";
  auto dummyMainDependencies =
      ModuleDependencyInfo::forSwiftSourceModule({}, {}, {}, {});
  std::for_each(newOverlays.begin(), newOverlays.end(),
                [&](Identifier modName) {
                  dummyMainDependencies.addModuleImport(modName.str());
                });

  // Record the dummy main module's direct dependencies. The dummy main module
  // only directly depend on these newly discovered overlay modules.
  if (cache.findDependency(dummyMainName, ModuleDependencyKind::SwiftSource)) {
    cache.updateDependency(
        ModuleDependencyID{dummyMainName.str(),
                           ModuleDependencyKind::SwiftSource},
        dummyMainDependencies);
  } else {
    cache.recordDependency(dummyMainName, dummyMainDependencies);
  }

  ModuleDependencyIDSetVector allModules;

  // Seed the all module list from the dummy main module.
  allModules.insert({dummyMainName.str(), dummyMainDependencies.getKind()});

  // Explore the dependencies of every module.
  for (unsigned currentModuleIdx = 0; currentModuleIdx < allModules.size();
       ++currentModuleIdx) {
    auto module = allModules[currentModuleIdx];
    auto moduleDependnencyIDs = resolveDirectModuleDependencies(module, cache);
    allModules.insert(moduleDependnencyIDs.begin(), moduleDependnencyIDs.end());
  }

  // Update main module's dependencies to include these new overlays.
  auto mainDep =
      *(cache.findDependency(mainModuleName, ModuleDependencyKind::SwiftSource)
            .value());
  std::for_each(/* +1 to exclude dummy main*/ allModules.begin() + 1,
                allModules.end(), [&](ModuleDependencyID dependencyID) {
                  mainDep.addModuleDependency(dependencyID);
                });
  cache.updateDependency(
      {mainModuleName.str(), ModuleDependencyKind::SwiftSource}, mainDep);

  // Report any discovered modules to the clients, which include all overlays
  // and their dependencies.
  std::for_each(/* +1 to exclude dummy main*/ allModules.begin() + 1,
                allModules.end(), action);
}
