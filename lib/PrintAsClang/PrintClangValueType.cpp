//===--- PrintClangValueType.cpp - Printer for C/C++ value types *- C++ -*-===//
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

#include "PrintClangValueType.h"
#include "ClangSyntaxPrinter.h"
#include "OutputLanguageMode.h"
#include "PrimitiveTypeMapping.h"
#include "SwiftToClangInteropContext.h"
#include "swift/AST/ASTMangler.h"
#include "swift/AST/Decl.h"
#include "swift/AST/ParameterList.h"
#include "swift/AST/Type.h"
#include "swift/AST/TypeVisitor.h"
#include "swift/ClangImporter/ClangImporter.h"
#include "swift/IRGen/IRABIDetailsProvider.h"
#include "swift/IRGen/Linking.h"
#include "llvm/ADT/STLExtras.h"

using namespace swift;

/// Print out the C type name of a struct/enum declaration.
static void printCTypeName(raw_ostream &os, const NominalTypeDecl *type,
                           ArrayRef<Type> genericArgs) {
  ClangSyntaxPrinter printer(os);
  printer.printModuleNameCPrefix(*type->getParentModule());
  // FIXME: add nested type qualifiers to fully disambiguate the name.
  printer.printBaseName(type);
  if (!genericArgs.empty()) {
    os << '_';
    llvm::interleave(
        genericArgs, os,
        [&](Type t) {
          swift::Mangle::ASTMangler mangler;
          os << mangler.mangleTypeWithoutPrefix(t);
        },
        "_");
  }
}

/// Print out the C++ type name of a struct/enum declaration.
static void printCxxTypeName(raw_ostream &os, const NominalTypeDecl *type,
                             const ModuleDecl *moduleContext) {
  ClangSyntaxPrinter(os).printPrimaryCxxTypeName(type, moduleContext);
}

void ClangValueTypePrinter::printCxxImplClassName(raw_ostream &os,
                                                  const NominalTypeDecl *type) {
  os << "_impl_";
  ClangSyntaxPrinter(os).printBaseName(type);
}

void ClangValueTypePrinter::printMetadataAccessAsVariable(
    raw_ostream &os, StringRef metadataFuncName,
    ArrayRef<GenericRequirement> genericRequirements, int indent,
    StringRef varName) {
  ClangSyntaxPrinter printer(os);
  os << std::string(indent, ' ') << "auto " << varName << " = "
     << cxx_synthesis::getCxxImplNamespaceName() << "::";
  printer.printSwiftTypeMetadataAccessFunctionCall(metadataFuncName,
                                                   genericRequirements);
  os << ";\n";
}

void ClangValueTypePrinter::printValueWitnessTableAccessAsVariable(
    raw_ostream &os, StringRef metadataFuncName,
    ArrayRef<GenericRequirement> genericRequirements, int indent,
    StringRef metadataVarName, StringRef vwTableVarName) {
  ClangSyntaxPrinter printer(os);
  printMetadataAccessAsVariable(os, metadataFuncName, genericRequirements,
                                indent, metadataVarName);
  printer.printValueWitnessTableAccessSequenceFromTypeMetadata(
      metadataVarName, vwTableVarName, indent);
}

static void
printCValueTypeStorageStruct(raw_ostream &os, const NominalTypeDecl *typeDecl,
                             IRABIDetailsProvider::SizeAndAlignment layout) {
  os << "struct ";
  printCTypeName(os, typeDecl, /*genericArgs=*/{});
  os << " {\n";
  os << "  _Alignas(" << layout.alignment << ") ";
  os << "char _storage[" << layout.size << "];\n";
  os << "};\n\n";
}

void ClangValueTypePrinter::forwardDeclType(raw_ostream &os,
                                            const NominalTypeDecl *typeDecl) {
  if (typeDecl->isGeneric()) {
    auto genericSignature =
        typeDecl->getGenericSignature().getCanonicalSignature();
    ClangSyntaxPrinter(os).printGenericSignature(genericSignature);
  }
  os << "class ";
  ClangSyntaxPrinter(os).printBaseName(typeDecl);
  os << ";\n";
}

static void addCppExtensionsToStdlibType(const NominalTypeDecl *typeDecl,
                                         ClangSyntaxPrinter &printer,
                                         raw_ostream &cPrologueOS) {
  if (typeDecl == typeDecl->getASTContext().getStringDecl()) {
    // Perform String -> NSString conversion using
    // _bridgeToObjectiveCImpl.
    // FIXME: This is an extension, we should
    // just expose the method to C once extensions are
    // supported.
    cPrologueOS << "SWIFT_EXTERN void *_Nonnull "
                   "$sSS23_bridgeToObjectiveCImplyXlyF(swift_interop_stub_"
                   "Swift_String) SWIFT_NOEXCEPT SWIFT_CALL;\n";
    printer.printObjCBlock([](raw_ostream &os) {
      os << "  ";
      ClangSyntaxPrinter(os).printInlineForThunk();
      os << "operator NSString * _Nonnull () const noexcept {\n";
      os << "    return (__bridge_transfer NSString "
            "*)(_impl::$sSS23_bridgeToObjectiveCImplyXlyF(_impl::swift_interop_"
            "passDirect_Swift_String(_getOpaquePointer())));\n";
      os << "  }\n";
    });
  }
}

void ClangValueTypePrinter::printValueTypeDecl(
    const NominalTypeDecl *typeDecl,
    llvm::function_ref<void(void)> bodyPrinter) {
  // FIXME: Add support for generic structs.
  llvm::Optional<IRABIDetailsProvider::SizeAndAlignment> typeSizeAlign;
  Optional<CanGenericSignature> genericSignature;
  auto printGenericSignature = [&](raw_ostream &os) {
    if (!genericSignature)
      return;
    ClangSyntaxPrinter(os).printGenericSignature(*genericSignature);
  };
  auto printGenericParamRefs = [&](raw_ostream &os) {
    if (!genericSignature)
      return;
    ClangSyntaxPrinter(os).printGenericSignatureParams(*genericSignature);
  };
  if (typeDecl->isGeneric()) {
    genericSignature = typeDecl->getGenericSignature().getCanonicalSignature();
    // FIXME: Support generic requirements.
    if (!genericSignature->getRequirements().empty())
      return;
    // FIXME: Can we make some better layout than opaque layout for generic
    // types.
  } else if (!typeDecl->isResilient()) {

    typeSizeAlign =
        interopContext.getIrABIDetails().getTypeSizeAlignment(typeDecl);
    assert(typeSizeAlign && "unknown layout for non-resilient type!");
    if (typeSizeAlign->size == 0) {
      // FIXME: How to represent 0 sized structs?
      return;
    }
  }
  bool isOpaqueLayout = !typeSizeAlign.hasValue();

  ClangSyntaxPrinter printer(os);

  auto typeMetadataFunc = irgen::LinkEntity::forTypeMetadataAccessFunction(
      typeDecl->getDeclaredType()->getCanonicalType());
  std::string typeMetadataFuncName = typeMetadataFunc.mangleAsString();
  auto typeMetadataFuncGenericParams =
      interopContext.getIrABIDetails()
          .getTypeMetadataAccessFunctionGenericRequirementParameters(
              const_cast<NominalTypeDecl *>(typeDecl));

  // Print out a forward declaration of the "hidden" _impl class.
  printer.printNamespace(cxx_synthesis::getCxxImplNamespaceName(),
                         [&](raw_ostream &os) {
                           printGenericSignature(os);
                           os << "class ";
                           printCxxImplClassName(os, typeDecl);
                           os << ";\n\n";

                           // Print out special functions, like functions that
                           // access type metadata.
                           printer.printCTypeMetadataTypeFunction(
                               typeDecl, typeMetadataFuncName,
                               typeMetadataFuncGenericParams);
                           // Print out global variables for resilient enum
                           // cases
                           if (isa<EnumDecl>(typeDecl) && isOpaqueLayout) {
                             auto elementTagMapping =
                                 interopContext.getIrABIDetails()
                                     .getEnumTagMapping(
                                         cast<EnumDecl>(typeDecl));
                             os << "// Tags for resilient enum ";
                             os << typeDecl->getName().str() << '\n';
                             os << "extern \"C\" {\n";
                             for (const auto &pair : elementTagMapping) {
                               os << "extern unsigned "
                                  << pair.second.globalVariableName << ";\n";
                             }
                             os << "}\n";
                           }
                         });

  auto printEnumVWTableVariable = [&](StringRef metadataName = "metadata",
                                      StringRef vwTableName = "vwTable",
                                      StringRef enumVWTableName =
                                          "enumVWTable") {
    ClangValueTypePrinter::printValueWitnessTableAccessAsVariable(
        os, typeMetadataFuncName, typeMetadataFuncGenericParams);
    os << "    const auto *" << enumVWTableName << " = reinterpret_cast<";
    ClangSyntaxPrinter(os).printSwiftImplQualifier();
    os << "EnumValueWitnessTable";
    os << " *>(" << vwTableName << ");\n";
  };

  // Print out the C++ class itself.
  printGenericSignature(os);
  os << "class ";
  ClangSyntaxPrinter(os).printBaseName(typeDecl);
  os << " final {\n";
  os << "public:\n";

  // Print out the destructor.
  os << "  inline ~";
  printer.printBaseName(typeDecl);
  os << "() {\n";
  ClangValueTypePrinter::printValueWitnessTableAccessAsVariable(
      os, typeMetadataFuncName, typeMetadataFuncGenericParams);
  os << "    vwTable->destroy(_getOpaquePointer(), metadata._0);\n";
  os << "  }\n";

  os << "  inline ";
  printer.printBaseName(typeDecl);
  os << "(const ";
  printer.printBaseName(typeDecl);
  os << " &other) {\n";
  ClangValueTypePrinter::printValueWitnessTableAccessAsVariable(
      os, typeMetadataFuncName, typeMetadataFuncGenericParams);
  if (isOpaqueLayout) {
    os << "    _storage = ";
    printer.printSwiftImplQualifier();
    os << cxx_synthesis::getCxxOpaqueStorageClassName()
       << "(vwTable->size, vwTable->getAlignment());\n";
  }
  os << "    vwTable->initializeWithCopy(_getOpaquePointer(), const_cast<char "
        "*>(other._getOpaquePointer()), metadata._0);\n";
  os << "  }\n";

  // FIXME: the move constructor should be hidden somehow.
  os << "  inline ";
  printer.printBaseName(typeDecl);
  os << "(";
  printer.printBaseName(typeDecl);
  os << " &&) = default;\n";

  bodyPrinter();
  if (typeDecl->isStdlibDecl())
    addCppExtensionsToStdlibType(typeDecl, printer, cPrologueOS);

  os << "private:\n";

  // Print out private default constructor.
  os << "  inline ";
  printer.printBaseName(typeDecl);
  // FIXME: make noexcept.
  if (isOpaqueLayout) {
    os << "(";
    printer.printSwiftImplQualifier();
    os << "ValueWitnessTable * _Nonnull vwTable) : _storage(vwTable->size, "
          "vwTable->getAlignment()) {}\n";
  } else {
    os << "() {}\n";
  }
  // Print out '_make' function which returns an unitialized instance for
  // passing to Swift.
  os << "  static inline ";
  printer.printBaseName(typeDecl);
  os << " _make() {";
  if (isOpaqueLayout) {
    os << "\n";
    ClangValueTypePrinter::printValueWitnessTableAccessAsVariable(
        os, typeMetadataFuncName, typeMetadataFuncGenericParams);
    os << "    return ";
    printer.printBaseName(typeDecl);
    os << "(vwTable);\n  }\n";
  } else {
    os << " return ";
    printer.printBaseName(typeDecl);
    os << "(); }\n";
  }
  // Print out the private accessors to the underlying Swift value storage.
  os << "  inline const char * _Nonnull _getOpaquePointer() const { return "
        "_storage";
  if (isOpaqueLayout)
    os << ".getOpaquePointer()";
  os << "; }\n";
  os << "  inline char * _Nonnull _getOpaquePointer() { return _storage";
  if (isOpaqueLayout)
    os << ".getOpaquePointer()";
  os << "; }\n";
  os << "\n";
  // Print out helper function for enums
  if (isa<EnumDecl>(typeDecl)) {
    os << "  inline char * _Nonnull _destructiveProjectEnumData() {\n";
    printEnumVWTableVariable();
    os << "    enumVWTable->destructiveProjectEnumData(_getOpaquePointer(), "
          "metadata._0);\n";
    os << "    return _getOpaquePointer();\n";
    os << "  }\n";
    os << "  inline void _destructiveInjectEnumTag(unsigned tag) {\n";
    printEnumVWTableVariable();
    os << "    enumVWTable->destructiveInjectEnumTag(_getOpaquePointer(), tag, "
          "metadata._0);\n";
    os << "  }\n";
    os << "  inline unsigned _getEnumTag() const {\n";
    printEnumVWTableVariable();
    os << "    return enumVWTable->getEnumTag(_getOpaquePointer(), "
          "metadata._0);\n";
    os << "  }\n";

    for (const auto &pair : interopContext.getIrABIDetails().getEnumTagMapping(
             cast<EnumDecl>(typeDecl))) {
      os << "  using _impl_" << pair.first->getNameStr() << " = decltype(";
      ClangSyntaxPrinter(os).printIdentifier(pair.first->getNameStr());
      os << ");\n";
    }
  }
  // Print out the storage for the value type.
  os << "  ";
  if (isOpaqueLayout) {
    printer.printSwiftImplQualifier();
    os << cxx_synthesis::getCxxOpaqueStorageClassName() << " _storage;\n";
  } else {
    os << "alignas(" << typeSizeAlign->alignment << ") ";
    os << "char _storage[" << typeSizeAlign->size << "];\n";
  }
  // Wrap up the value type.
  os << "  friend class " << cxx_synthesis::getCxxImplNamespaceName() << "::";
  printCxxImplClassName(os, typeDecl);
  printGenericParamRefs(os);
  os << ";\n";
  os << "};\n";
  os << '\n';

  const auto *moduleContext = typeDecl->getModuleContext();
  // Print out the "hidden" _impl class.
  printer.printNamespace(
      cxx_synthesis::getCxxImplNamespaceName(), [&](raw_ostream &os) {
        printGenericSignature(os);
        os << "class ";
        printCxxImplClassName(os, typeDecl);
        os << " {\n";
        os << "public:\n";

        os << "  static inline char * _Nonnull getOpaquePointer(";
        printCxxTypeName(os, typeDecl, moduleContext);
        printGenericParamRefs(os);
        os << " &object) { return object._getOpaquePointer(); }\n";

        os << "  static inline const char * _Nonnull getOpaquePointer(const ";
        printCxxTypeName(os, typeDecl, moduleContext);
        printGenericParamRefs(os);
        os << " &object) { return object._getOpaquePointer(); }\n";

        os << "  template<class T>\n";
        os << "  static inline ";
        printCxxTypeName(os, typeDecl, moduleContext);
        printGenericParamRefs(os);
        os << " returnNewValue(T callable) {\n";
        os << "    auto result = ";
        printCxxTypeName(os, typeDecl, moduleContext);
        printGenericParamRefs(os);
        os << "::_make();\n";
        os << "    callable(result._getOpaquePointer());\n";
        os << "    return result;\n";
        os << "  }\n";
        // Print out helper function for initializeWithTake
        os << "  static inline void initializeWithTake(char * _Nonnull "
              "destStorage, char * _Nonnull srcStorage) {\n";
        ClangValueTypePrinter::printValueWitnessTableAccessAsVariable(
            os, typeMetadataFuncName, typeMetadataFuncGenericParams);
        os << "    vwTable->initializeWithTake(destStorage, srcStorage, "
              "metadata._0);\n";
        os << "  }\n";
        os << "};\n";
      });

  if (!isOpaqueLayout)
    printCValueTypeStorageStruct(cPrologueOS, typeDecl, *typeSizeAlign);

  printTypeGenericTraits(os, typeDecl, typeMetadataFuncName,
                         typeMetadataFuncGenericParams);
}

/// Print out the C stub struct that's used to pass/return a value type directly
/// to/from swiftcc function.
static void
printCStructStubForDirectPassing(raw_ostream &os, StringRef stubName, Type type,
                                 PrimitiveTypeMapping &typeMapping,
                                 SwiftToClangInteropContext &interopContext) {
  // Print out a C stub for this value type.
  os << "// Stub struct to be used to pass/return values to/from Swift "
        "functions.\n";
  os << "struct " << stubName << " {\n";
  llvm::SmallVector<std::pair<clang::CharUnits, clang::CharUnits>, 8> fields;
  interopContext.getIrABIDetails().enumerateDirectPassingRecordMembers(
      type, [&](clang::CharUnits offset, clang::CharUnits end, Type t) {
        auto info =
            typeMapping.getKnownCTypeInfo(t->getNominalOrBoundGenericNominal());
        if (!info)
          return;
        os << "  " << info->name;
        if (info->canBeNullable)
          os << " _Null_unspecified";
        os << " _" << (fields.size() + 1) << ";\n";
        fields.push_back(std::make_pair(offset, end));
      });
  os << "};\n\n";
  auto minimalStubName = stubName;
  minimalStubName.consume_front("swift_interop_stub_");

  // Emit a stub that returns a value directly from swiftcc function.
  os << "static inline void swift_interop_returnDirect_" << minimalStubName;
  os << "(char * _Nonnull result, struct " << stubName << " value";
  os << ") __attribute__((always_inline)) {\n";
  for (size_t i = 0; i < fields.size(); ++i) {
    os << "  memcpy(result + " << fields[i].first.getQuantity() << ", "
       << "&value._" << (i + 1) << ", "
       << (fields[i].second - fields[i].first).getQuantity() << ");\n";
  }
  os << "}\n\n";

  // Emit a stub that is used to pass value type directly to swiftcc function.
  os << "static inline struct " << stubName << " swift_interop_passDirect_"
     << minimalStubName;
  os << "(const char * _Nonnull value) __attribute__((always_inline)) {\n";
  os << "  struct " << stubName << " result;\n";
  for (size_t i = 0; i < fields.size(); ++i) {
    os << "  memcpy(&result._" << (i + 1) << ", value + "
       << fields[i].first.getQuantity() << ", "
       << (fields[i].second - fields[i].first).getQuantity() << ");\n";
  }
  os << "  return result;\n";
  os << "}\n\n";
}

void ClangValueTypePrinter::printParameterCxxToCUseScaffold(
    bool isIndirect, const NominalTypeDecl *type, ArrayRef<Type> genericArgs,
    const ModuleDecl *moduleContext, llvm::function_ref<void()> typePrinter,
    llvm::function_ref<void()> cxxParamPrinter, bool isInOut, bool isSelf) {
  // A Swift value type is passed to its underlying Swift function
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  if (!isIndirect && !isInOut) {
    os << cxx_synthesis::getCxxImplNamespaceName() << "::"
       << "swift_interop_passDirect_";
    printCTypeName(os, type, genericArgs);
    os << '(';
  }
  if (isSelf) {
    os << "_getOpaquePointer()";
  } else {
    // FIXME: can we propagate the _impl request here?
    typePrinter();
    os << "::getOpaquePointer(";
    cxxParamPrinter();
    os << ')';
  }
  if (!isIndirect && !isInOut) {
    os << ')';
  }
}

void ClangValueTypePrinter::printValueTypeReturnType(
    const NominalTypeDecl *type, OutputLanguageMode outputLang,
    TypeUseKind typeUse, const ModuleDecl *moduleContext) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  assert(outputLang == OutputLanguageMode::Cxx);
  // FIXME: make a type use.
  if (outputLang == OutputLanguageMode::Cxx) {
    if (typeUse == TypeUseKind::CxxTypeName)
      printCxxTypeName(os, type, moduleContext);
    else {
      assert(typeUse == TypeUseKind::CxxImplTypeName);
      ClangSyntaxPrinter(os).printModuleNamespaceQualifiersIfNeeded(
          type->getModuleContext(), moduleContext);
      os << cxx_synthesis::getCxxImplNamespaceName() << "::";
      printCxxImplClassName(os, type);
    }
  }
}

void ClangValueTypePrinter::printCStubType(Type type,
                                           const NominalTypeDecl *typeDecl,
                                           ArrayRef<Type> genericArgs) {
  os << "struct ";
  std::string stubName;
  {
    llvm::raw_string_ostream stubNameOS(stubName);
    stubNameOS << "swift_interop_stub_";
    printCTypeName(stubNameOS, typeDecl, genericArgs);
  }
  os << stubName;
  // Ensure the stub is declared in the header.
  interopContext.runIfStubForDeclNotEmitted(stubName, [&]() {
    printCStructStubForDirectPassing(cPrologueOS, stubName, type, typeMapping,
                                     interopContext);
  });
}

void ClangValueTypePrinter::printValueTypeIndirectReturnScaffold(
    const NominalTypeDecl *type, const ModuleDecl *moduleContext,
    llvm::function_ref<void()> typePrinter,
    llvm::function_ref<void(StringRef)> bodyPrinter) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  os << "  return ";
  typePrinter();
  os << "::returnNewValue([&](void * _Nonnull result) {\n    ";
  bodyPrinter("result");
  os << ";\n";
  os << "  });\n";
}

void ClangValueTypePrinter::printValueTypeDirectReturnScaffold(
    const NominalTypeDecl *type, ArrayRef<Type> genericArgs,
    const ModuleDecl *moduleContext, llvm::function_ref<void()> typePrinter,
    llvm::function_ref<void()> bodyPrinter) {
  assert(isa<StructDecl>(type) || isa<EnumDecl>(type));
  os << "  return ";
  typePrinter();
  os << "::returnNewValue([&](char * _Nonnull result) {\n";
  os << "    ";
  os << cxx_synthesis::getCxxImplNamespaceName() << "::"
     << "swift_interop_returnDirect_";
  printCTypeName(os, type, genericArgs);
  os << "(result, ";
  bodyPrinter();
  os << ");\n";
  os << "  });\n";
}

void ClangValueTypePrinter::printTypeGenericTraits(
    raw_ostream &os, const NominalTypeDecl *typeDecl,
    StringRef typeMetadataFuncName,
    ArrayRef<GenericRequirement> typeMetadataFuncRequirements) {
  ClangSyntaxPrinter printer(os);
  // FIXME: avoid popping out of the module's namespace here.
  os << "} // end namespace \n\n";
  os << "namespace swift {\n";

  os << "#pragma clang diagnostic push\n";
  os << "#pragma clang diagnostic ignored \"-Wc++17-extensions\"\n";
  if (typeMetadataFuncRequirements.empty()) {
    // FIXME: generic type support.
    os << "template<>\n";
    os << "static inline const constexpr bool isUsableInGenericContext<";
    printer.printBaseName(typeDecl->getModuleContext());
    os << "::";
    printer.printBaseName(typeDecl);
    os << "> = true;\n";
  }
  if (printer.printNominalTypeOutsideMemberDeclTemplateSpecifiers(typeDecl))
    os << "template<>\n";
  os << "struct TypeMetadataTrait<";
  printer.printNominalTypeReference(typeDecl,
                                    /*moduleContext=*/nullptr);
  os << "> {\n";
  os << "  static inline void * _Nonnull getTypeMetadata() {\n";
  os << "    return ";
  printer.printBaseName(typeDecl->getModuleContext());
  os << "::" << cxx_synthesis::getCxxImplNamespaceName() << "::";
  ClangSyntaxPrinter(os).printSwiftTypeMetadataAccessFunctionCall(
      typeMetadataFuncName, typeMetadataFuncRequirements);
  os << "._0;\n";
  os << "  }\n};\n";

  os << "namespace " << cxx_synthesis::getCxxImplNamespaceName() << "{\n";

  if (!isa<ClassDecl>(typeDecl) && typeMetadataFuncRequirements.empty()) {
    // FIXME: generic support.
    os << "template<>\n";
    os << "static inline const constexpr bool isValueType<";
    printer.printBaseName(typeDecl->getModuleContext());
    os << "::";
    printer.printBaseName(typeDecl);
    os << "> = true;\n";
    if (typeDecl->isResilient()) {
      os << "template<>\n";
      os << "static inline const constexpr bool isOpaqueLayout<";
      printer.printBaseName(typeDecl->getModuleContext());
      os << "::";
      printer.printBaseName(typeDecl);
      os << "> = true;\n";
    }
  }

  // FIXME: generic support.
  if (typeMetadataFuncRequirements.empty()) {
    os << "template<>\n";
    os << "struct implClassFor<";
    printer.printBaseName(typeDecl->getModuleContext());
    os << "::";
    printer.printBaseName(typeDecl);
    os << "> { using type = ";
    printer.printBaseName(typeDecl->getModuleContext());
    os << "::" << cxx_synthesis::getCxxImplNamespaceName() << "::";
    printCxxImplClassName(os, typeDecl);
    os << "; };\n";
  }
  os << "} // namespace\n";
  os << "#pragma clang diagnostic pop\n";
  os << "} // namespace swift\n";
  os << "\nnamespace ";
  printer.printBaseName(typeDecl->getModuleContext());
  os << " {\n";
}
