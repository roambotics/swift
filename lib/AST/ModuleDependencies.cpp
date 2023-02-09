//===--- ModuleDependencies.h - Module Dependencies -------------*- C++ -*-===//
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
//
// This file implements data structures for capturing module dependencies.
//
//===----------------------------------------------------------------------===//
#include "swift/AST/ModuleDependencies.h"
#include "swift/AST/Decl.h"
#include "swift/AST/SourceFile.h"
#include "swift/Frontend/Frontend.h"
using namespace swift;

ModuleDependencyInfoStorageBase::~ModuleDependencyInfoStorageBase() {}

bool ModuleDependencyInfo::isSwiftModule() const {
  return isSwiftInterfaceModule() || isSwiftSourceModule() ||
         isSwiftBinaryModule() || isSwiftPlaceholderModule();
}

ModuleDependencyKind &operator++(ModuleDependencyKind &e) {
  if (e == ModuleDependencyKind::LastKind) {
    llvm_unreachable(
        "Attempting to increment last enum value on ModuleDependencyKind");
  }
  e = ModuleDependencyKind(
      static_cast<std::underlying_type<ModuleDependencyKind>::type>(e) + 1);
  return e;
}

bool ModuleDependencyInfo::isSwiftInterfaceModule() const {
  return isa<SwiftInterfaceModuleDependenciesStorage>(storage.get());
}

bool ModuleDependencyInfo::isSwiftSourceModule() const {
  return isa<SwiftSourceModuleDependenciesStorage>(storage.get());
}

bool ModuleDependencyInfo::isSwiftBinaryModule() const {
  return isa<SwiftBinaryModuleDependencyStorage>(storage.get());
}

bool ModuleDependencyInfo::isSwiftPlaceholderModule() const {
  return isa<SwiftPlaceholderModuleDependencyStorage>(storage.get());
}

bool ModuleDependencyInfo::isClangModule() const {
  return isa<ClangModuleDependencyStorage>(storage.get());
}

/// Retrieve the dependencies for a Swift textual interface module.
const SwiftInterfaceModuleDependenciesStorage *
ModuleDependencyInfo::getAsSwiftInterfaceModule() const {
  return dyn_cast<SwiftInterfaceModuleDependenciesStorage>(storage.get());
}

const SwiftSourceModuleDependenciesStorage *
ModuleDependencyInfo::getAsSwiftSourceModule() const {
  return dyn_cast<SwiftSourceModuleDependenciesStorage>(storage.get());
}

/// Retrieve the dependencies for a binary Swift dependency module.
const SwiftBinaryModuleDependencyStorage *
ModuleDependencyInfo::getAsSwiftBinaryModule() const {
  return dyn_cast<SwiftBinaryModuleDependencyStorage>(storage.get());
}

/// Retrieve the dependencies for a Clang module.
const ClangModuleDependencyStorage *
ModuleDependencyInfo::getAsClangModule() const {
  return dyn_cast<ClangModuleDependencyStorage>(storage.get());
}

/// Retrieve the dependencies for a placeholder dependency module stub.
const SwiftPlaceholderModuleDependencyStorage *
ModuleDependencyInfo::getAsPlaceholderDependencyModule() const {
  return dyn_cast<SwiftPlaceholderModuleDependencyStorage>(storage.get());
}

void ModuleDependencyInfo::addModuleDependency(ModuleDependencyID dependencyID) {
  storage->resolvedModuleDependencies.push_back(dependencyID);
}

void ModuleDependencyInfo::addModuleImport(
    StringRef module, llvm::StringSet<> *alreadyAddedModules) {
  if (!alreadyAddedModules || alreadyAddedModules->insert(module).second)
    storage->moduleImports.push_back(module.str());
}

void ModuleDependencyInfo::addModuleImport(
    const SourceFile &sf, llvm::StringSet<> &alreadyAddedModules) {
  // Add all of the module dependencies.
  SmallVector<Decl *, 32> decls;
  sf.getTopLevelDecls(decls);
  for (auto decl : decls) {
    auto importDecl = dyn_cast<ImportDecl>(decl);
    if (!importDecl)
      continue;

    ImportPath::Builder scratch;
    auto realPath = importDecl->getRealModulePath(scratch);
    addModuleImport(realPath, &alreadyAddedModules);
  }

  auto fileName = sf.getFilename();
  if (fileName.empty())
    return;

  switch (getKind()) {
  case swift::ModuleDependencyKind::SwiftInterface: {
    // If the storage is for an interface file, the only source file we
    // should see is that interface file.
    auto swiftInterfaceStorage =
        cast<SwiftInterfaceModuleDependenciesStorage>(storage.get());
    assert(fileName == swiftInterfaceStorage->swiftInterfaceFile);
    break;
  }
  case swift::ModuleDependencyKind::SwiftSource: {
    // Otherwise, record the source file.
    auto swiftSourceStorage =
        cast<SwiftSourceModuleDependenciesStorage>(storage.get());
    swiftSourceStorage->sourceFiles.push_back(fileName.str());
    break;
  }
  default:
    llvm_unreachable("Unexpected dependency kind");
  }
}

Optional<std::string> ModuleDependencyInfo::getBridgingHeader() const {
  switch (getKind()) {
  case swift::ModuleDependencyKind::SwiftInterface: {
    auto swiftInterfaceStorage =
        cast<SwiftInterfaceModuleDependenciesStorage>(storage.get());
    return swiftInterfaceStorage->textualModuleDetails.bridgingHeaderFile;
  }
  case swift::ModuleDependencyKind::SwiftSource: {
    auto swiftSourceStorage =
        cast<SwiftSourceModuleDependenciesStorage>(storage.get());
    return swiftSourceStorage->textualModuleDetails.bridgingHeaderFile;
  }
  default:
    llvm_unreachable("Unexpected dependency kind");
  }
}

void ModuleDependencyInfo::addBridgingHeader(StringRef bridgingHeader) {
  switch (getKind()) {
  case swift::ModuleDependencyKind::SwiftInterface: {
    auto swiftInterfaceStorage =
        cast<SwiftInterfaceModuleDependenciesStorage>(storage.get());
    assert(!swiftInterfaceStorage->textualModuleDetails.bridgingHeaderFile);
    swiftInterfaceStorage->textualModuleDetails.bridgingHeaderFile = bridgingHeader.str();
    break;
  }
  case swift::ModuleDependencyKind::SwiftSource: {
    auto swiftSourceStorage =
        cast<SwiftSourceModuleDependenciesStorage>(storage.get());
    assert(!swiftSourceStorage->textualModuleDetails.bridgingHeaderFile);
    swiftSourceStorage->textualModuleDetails.bridgingHeaderFile = bridgingHeader.str();
    break;
  }
  default:
    llvm_unreachable("Unexpected dependency kind");
  }
}

/// Add source files that the bridging header depends on.
void ModuleDependencyInfo::addBridgingSourceFile(StringRef bridgingSourceFile) {
  switch (getKind()) {
  case swift::ModuleDependencyKind::SwiftInterface: {
    auto swiftInterfaceStorage =
        cast<SwiftInterfaceModuleDependenciesStorage>(storage.get());
    swiftInterfaceStorage->textualModuleDetails.bridgingSourceFiles.push_back(
        bridgingSourceFile.str());
    break;
  }
  case swift::ModuleDependencyKind::SwiftSource: {
    auto swiftSourceStorage =
        cast<SwiftSourceModuleDependenciesStorage>(storage.get());
    swiftSourceStorage->textualModuleDetails.bridgingSourceFiles.push_back(bridgingSourceFile.str());
    break;
  }
  default:
    llvm_unreachable("Unexpected dependency kind");
  }
}

void ModuleDependencyInfo::addSourceFile(StringRef sourceFile) {
  switch (getKind()) {
  case swift::ModuleDependencyKind::SwiftSource: {
    auto swiftSourceStorage =
        cast<SwiftSourceModuleDependenciesStorage>(storage.get());
    swiftSourceStorage->sourceFiles.push_back(sourceFile.str());
    break;
  }
  default:
    llvm_unreachable("Unexpected dependency kind");
  }
}

/// Add (Clang) module on which the bridging header depends.
void ModuleDependencyInfo::addBridgingModuleDependency(
    StringRef module, llvm::StringSet<> &alreadyAddedModules) {
  switch (getKind()) {
  case swift::ModuleDependencyKind::SwiftInterface: {
    auto swiftInterfaceStorage =
        cast<SwiftInterfaceModuleDependenciesStorage>(storage.get());
    if (alreadyAddedModules.insert(module).second)
      swiftInterfaceStorage->textualModuleDetails.bridgingModuleDependencies.push_back(module.str());
    break;
  }
  case swift::ModuleDependencyKind::SwiftSource: {
    auto swiftSourceStorage =
        cast<SwiftSourceModuleDependenciesStorage>(storage.get());
    if (alreadyAddedModules.insert(module).second)
      swiftSourceStorage->textualModuleDetails.bridgingModuleDependencies.push_back(module.str());
    break;
  }
  default:
    llvm_unreachable("Unexpected dependency kind");
  }
}

SwiftDependencyScanningService::SwiftDependencyScanningService()
  : ClangScanningService(clang::tooling::dependencies::ScanningMode::DependencyDirectivesScan,
                         clang::tooling::dependencies::ScanningOutputFormat::Full,
                         clang::CASOptions(),
                         /* Cache (llvm::cas::ActionCache) */ nullptr,
                         /* SharedFS */ nullptr,
                         /* ReuseFileManager */ false,
                         /* OptimizeArgs */ false) {
    SharedFilesystemCache.emplace();
}

void SwiftDependencyScanningService::overlaySharedFilesystemCacheForCompilation(CompilerInstance &Instance) {
 auto existingFS = Instance.getSourceMgr().getFileSystem();
 llvm::IntrusiveRefCntPtr<
     clang::tooling::dependencies::DependencyScanningWorkerFilesystem>
     depFS =
         new clang::tooling::dependencies::DependencyScanningWorkerFilesystem(
             getSharedFilesystemCache(), existingFS);
 Instance.getSourceMgr().setFileSystem(depFS);
}

SwiftDependencyScanningService::ContextSpecificGlobalCacheState *
SwiftDependencyScanningService::getCurrentCache() const {
  assert(CurrentContextHash.has_value() &&
         "Global Module Dependencies Cache not configured with Triple.");
  return getCacheForScanningContextHash(CurrentContextHash.value());
}

SwiftDependencyScanningService::ContextSpecificGlobalCacheState *
SwiftDependencyScanningService::getCacheForScanningContextHash(StringRef scanningContextHash) const {
  auto contextSpecificCache = ContextSpecificCacheMap.find(scanningContextHash);
  assert(contextSpecificCache != ContextSpecificCacheMap.end() &&
         "Global Module Dependencies Cache not configured with context-specific "
         "state.");
  return contextSpecificCache->getValue().get();
}

const ModuleNameToDependencyMap &
SwiftDependencyScanningService::getDependenciesMap(
    ModuleDependencyKind kind) const {
  auto contextSpecificCache = getCurrentCache();
  auto it = contextSpecificCache->ModuleDependenciesMap.find(kind);
  assert(it != contextSpecificCache->ModuleDependenciesMap.end() &&
         "invalid dependency kind");
  return it->second;
}

ModuleNameToDependencyMap &
SwiftDependencyScanningService::getDependenciesMap(
    ModuleDependencyKind kind) {
  auto contextSpecificCache = getCurrentCache();
  auto it = contextSpecificCache->ModuleDependenciesMap.find(kind);
  assert(it != contextSpecificCache->ModuleDependenciesMap.end() &&
         "invalid dependency kind");
  return it->second;
}

void SwiftDependencyScanningService::configureForContextHash(std::string scanningContextHash) {
  auto knownContext = ContextSpecificCacheMap.find(scanningContextHash);
  if (knownContext != ContextSpecificCacheMap.end()) {
    // Set the current context and leave the rest as-is
    CurrentContextHash = scanningContextHash;
  } else {
    // First time scanning with this triple, initialize target-specific state.
    std::unique_ptr<ContextSpecificGlobalCacheState> contextSpecificCache =
        std::make_unique<ContextSpecificGlobalCacheState>();
    for (auto kind = ModuleDependencyKind::FirstKind;
         kind != ModuleDependencyKind::LastKind; ++kind) {
      contextSpecificCache->ModuleDependenciesMap.insert({kind, ModuleNameToDependencyMap()});
    }

    ContextSpecificCacheMap.insert({scanningContextHash, std::move(contextSpecificCache)});
    CurrentContextHash = scanningContextHash;
    AllContextHashes.push_back(scanningContextHash);
  }
}

Optional<const ModuleDependencyInfo*> SwiftDependencyScanningService::findDependency(
    StringRef moduleName, Optional<ModuleDependencyKind> kind) const {
  if (!kind) {
    for (auto kind = ModuleDependencyKind::FirstKind;
         kind != ModuleDependencyKind::LastKind; ++kind) {
      auto dep = findDependency(moduleName, kind);
      if (dep.has_value())
        return dep.value();
    }
    return None;
  }

  assert(kind.has_value() && "Expected dependencies kind for lookup.");
  if (kind.value() == swift::ModuleDependencyKind::SwiftSource) {
    return findSourceModuleDependency(moduleName);
  }

  const auto &map = getDependenciesMap(kind.value());
  auto known = map.find(moduleName);
  if (known != map.end())
    return &(known->second);

  return None;
}

Optional<const ModuleDependencyInfo*>
SwiftDependencyScanningService::findSourceModuleDependency(
    StringRef moduleName) const {
  auto known = SwiftSourceModuleDependenciesMap.find(moduleName);
  if (known != SwiftSourceModuleDependenciesMap.end())
    return &(known->second);
  else
    return None;
}

bool SwiftDependencyScanningService::hasDependency(
    StringRef moduleName, Optional<ModuleDependencyKind> kind) const {
  return findDependency(moduleName, kind).has_value();
}

const ModuleDependencyInfo *SwiftDependencyScanningService::recordDependency(
    StringRef moduleName, ModuleDependencyInfo dependencies) {
  auto kind = dependencies.getKind();
  // Source-based dependencies are recorded independently of the invocation's
  // target triple.
  if (kind == swift::ModuleDependencyKind::SwiftSource) {
    assert(SwiftSourceModuleDependenciesMap.count(moduleName) == 0 &&
           "Attempting to record duplicate SwiftSource dependency.");
    SwiftSourceModuleDependenciesMap.insert(
        {moduleName, std::move(dependencies)});
    AllSourceModules.push_back({moduleName.str(), kind});
    return &(SwiftSourceModuleDependenciesMap.find(moduleName)->second);
  }

  // All other dependencies are recorded according to the target triple of the
  // scanning invocation that discovers them.
  auto &map = getDependenciesMap(kind);
  map.insert({moduleName, dependencies});
  return &(map[moduleName]);
}

const ModuleDependencyInfo *SwiftDependencyScanningService::updateDependency(
    ModuleDependencyID moduleID, ModuleDependencyInfo dependencies) {
  auto kind = dependencies.getKind();
  // Source-based dependencies
  if (kind == swift::ModuleDependencyKind::SwiftSource) {
    assert(SwiftSourceModuleDependenciesMap.count(moduleID.first) == 1 &&
           "Attempting to update non-existing Swift Source dependency.");
    auto known = SwiftSourceModuleDependenciesMap.find(moduleID.first);
    known->second = std::move(dependencies);
    return &(known->second);
  }

  auto &map = getDependenciesMap(moduleID.second);
  auto known = map.find(moduleID.first);
  assert(known != map.end() && "Not yet added to map");
  known->second = std::move(dependencies);
  return &(known->second);
}

llvm::StringMap<const ModuleDependencyInfo *> &
ModuleDependenciesCache::getDependencyReferencesMap(
    ModuleDependencyKind kind) {
  auto it = ModuleDependenciesMap.find(kind);
  assert(it != ModuleDependenciesMap.end() && "invalid dependency kind");
  return it->second;
}

const llvm::StringMap<const ModuleDependencyInfo *> &
ModuleDependenciesCache::getDependencyReferencesMap(
    ModuleDependencyKind kind) const {
  auto it = ModuleDependenciesMap.find(kind);
  assert(it != ModuleDependenciesMap.end() && "invalid dependency kind");
  return it->second;
}

ModuleDependenciesCache::ModuleDependenciesCache(
    SwiftDependencyScanningService &globalScanningService,
    std::string mainScanModuleName,
    std::string scannerContextHash)
    : globalScanningService(globalScanningService),
      mainScanModuleName(mainScanModuleName),
      scannerContextHash(scannerContextHash),
      clangScanningTool(globalScanningService.ClangScanningService) {
  globalScanningService.configureForContextHash(scannerContextHash);
  for (auto kind = ModuleDependencyKind::FirstKind;
       kind != ModuleDependencyKind::LastKind; ++kind) {
    ModuleDependenciesMap.insert(
        {kind, llvm::StringMap<const ModuleDependencyInfo *>()});
  }
}

Optional<const ModuleDependencyInfo*>
ModuleDependenciesCache::findDependency(
    StringRef moduleName, Optional<ModuleDependencyKind> kind) const {
  auto optionalDep = globalScanningService.findDependency(moduleName, kind);
  // During a scan, only produce the cached source module info for the current module
  // under scan.
  if (optionalDep.hasValue()) {
    auto dep = optionalDep.getValue();
    if (dep->getAsSwiftSourceModule() &&
        moduleName != mainScanModuleName &&
        moduleName != "DummyMainModuleForResolvingCrossImportOverlays") {
      return None;
    }
  }

  return optionalDep;
}

bool ModuleDependenciesCache::hasDependency(
    StringRef moduleName, Optional<ModuleDependencyKind> kind) const {
  return findDependency(moduleName, kind).has_value();
}

void ModuleDependenciesCache::recordDependency(
    StringRef moduleName, ModuleDependencyInfo dependencies) {
  auto dependenciesKind = dependencies.getKind();
  const ModuleDependencyInfo *recordedDependencies =
        globalScanningService.recordDependency(moduleName, dependencies);

  auto &map = getDependencyReferencesMap(dependenciesKind);
  assert(map.count(moduleName) == 0 && "Already added to map");
  map.insert({moduleName, recordedDependencies});
}

void ModuleDependenciesCache::updateDependency(
    ModuleDependencyID moduleID, ModuleDependencyInfo dependencyInfo) {
  const ModuleDependencyInfo *updatedDependencies = globalScanningService.updateDependency(moduleID, dependencyInfo);
  auto &map = getDependencyReferencesMap(moduleID.second);
  auto known = map.find(moduleID.first);
  if (known != map.end())
    map.erase(known);
  map.insert({moduleID.first, updatedDependencies});
}

void ModuleDependenciesCache::resolveDependencyImports(ModuleDependencyID moduleID,
                                                       const std::vector<ModuleDependencyID> &dependencyIDs) {
  auto optionalDependencyInfo = findDependency(moduleID.first, moduleID.second);
  assert(optionalDependencyInfo.has_value() && "Resolving unknown dependency");
  // Copy the existing info to a mutable one we can then replace it with, after resolving its dependencies.
  auto dependencyInfo = *(optionalDependencyInfo.value());
  dependencyInfo.resolveDependencies(dependencyIDs);
  updateDependency(moduleID, dependencyInfo);
}
