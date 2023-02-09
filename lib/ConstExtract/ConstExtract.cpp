//===-------- ConstExtract.cpp -- Gather Compile-Time-Known Values --------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/ConstExtract/ConstExtract.h"
#include "swift/AST/ASTContext.h"
#include "swift/AST/ASTWalker.h"
#include "swift/AST/Decl.h"
#include "swift/AST/DiagnosticEngine.h"
#include "swift/AST/DiagnosticsFrontend.h"
#include "swift/AST/Evaluator.h"
#include "swift/AST/SourceFile.h"
#include "swift/AST/TypeCheckRequests.h"
#include "swift/Basic/TypeID.h"
#include "swift/ConstExtract/ConstExtractRequests.h"
#include "swift/Subsystems.h"
#include "llvm/ADT/PointerUnion.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/YAMLParser.h"
#include "llvm/Support/YAMLTraits.h"

#include <set>
#include <sstream>
#include <string>

using namespace swift;

namespace {
/// A helper class to collect all nominal type declarations that conform to
/// specific protocols provided as input.
class NominalTypeConformanceCollector : public ASTWalker {
  const std::unordered_set<std::string> &Protocols;
  std::vector<NominalTypeDecl *> &ConformanceTypeDecls;

public:
  NominalTypeConformanceCollector(
      const std::unordered_set<std::string> &Protocols,
      std::vector<NominalTypeDecl *> &ConformanceDecls)
      : Protocols(Protocols), ConformanceTypeDecls(ConformanceDecls) {}

  PreWalkAction walkToDeclPre(Decl *D) override {
    if (auto *NTD = llvm::dyn_cast<NominalTypeDecl>(D))
      if (!isa<ProtocolDecl>(NTD))
        for (auto &Protocol : NTD->getAllProtocols())
          if (Protocols.count(Protocol->getName().str().str()) != 0)
            ConformanceTypeDecls.push_back(NTD);
    return Action::Continue();
  }
};

std::string toFullyQualifiedTypeNameString(const swift::Type &Type) {
  std::string TypeNameOutput;
  llvm::raw_string_ostream OutputStream(TypeNameOutput);
  swift::PrintOptions Options;
  Options.FullyQualifiedTypes = true;
  Options.PreferTypeRepr = true;
  Options.AlwaysDesugarArraySliceTypes = true;
  Options.AlwaysDesugarDictionaryTypes = true;
  Options.AlwaysDesugarOptionalTypes = true;
  Type.print(OutputStream, Options);
  OutputStream.flush();
  return TypeNameOutput;
}

} // namespace

namespace swift {

bool
parseProtocolListFromFile(StringRef protocolListFilePath,
                          DiagnosticEngine &diags,
                          std::unordered_set<std::string> &protocols) {
  // Load the input file.
  llvm::ErrorOr<std::unique_ptr<llvm::MemoryBuffer>> FileBufOrErr =
      llvm::MemoryBuffer::getFile(protocolListFilePath);
  if (!FileBufOrErr) {
    diags.diagnose(SourceLoc(),
                   diag::const_extract_protocol_list_input_file_missing,
                   protocolListFilePath);
    return false;
  }

  // Parse a JSON file containing a list of the format:
  // [proto1, proto2, proto3]
  bool ParseFailed = false;
  {
    StringRef Buffer = FileBufOrErr->get()->getBuffer();
    llvm::SourceMgr SM;
    llvm::yaml::Stream S(Buffer, SM);
    llvm::yaml::SequenceNode *Sequence =
        dyn_cast<llvm::yaml::SequenceNode>(S.begin()->getRoot());
    if (Sequence) {
      for (auto &ProtocolNameNode : *Sequence) {
        auto *ScalarNode = dyn_cast<llvm::yaml::ScalarNode>(&ProtocolNameNode);
        if (!ScalarNode) {
          ParseFailed = true;
          break;
        }
        auto protocolNameStr = ScalarNode->getRawValue().str();
        if (protocolNameStr.front() == '"' && protocolNameStr.back() == '"')
          protocolNameStr = protocolNameStr.substr(1, protocolNameStr.size() - 2);
        protocols.insert(protocolNameStr);
      }
    } else
      ParseFailed = true;
  }

  if (ParseFailed) {
    diags.diagnose(SourceLoc(),
                   diag::const_extract_protocol_list_input_file_corrupted,
                   protocolListFilePath);
    return false;
  }
  return true;
}

static std::shared_ptr<CompileTimeValue> extractCompileTimeValue(Expr *expr);

static std::vector<FunctionParameter>
extractFunctionArguments(const ArgumentList *args) {
  std::vector<FunctionParameter> parameters;

  for (auto arg : *args) {
    auto argExpr = arg.getExpr();
    const auto label = arg.getLabel().str().str();
    const auto type = argExpr->getType();
    if (auto defaultArgument = dyn_cast<DefaultArgumentExpr>(argExpr)) {
      auto *decl = defaultArgument->getParamDecl();
      if (decl->hasDefaultExpr()) {
        argExpr = decl->getTypeCheckedDefaultExpr();
      }
    }
    parameters.push_back({label, type, extractCompileTimeValue(argExpr)});
  }

  return parameters;
}

static llvm::Optional<std::string> extractRawLiteral(Expr *expr) {
  if (expr) {
    switch (expr->getKind()) {
    case ExprKind::BooleanLiteral:
    case ExprKind::FloatLiteral:
    case ExprKind::IntegerLiteral:
    case ExprKind::NilLiteral: {
      std::string literalOutput;
      llvm::raw_string_ostream OutputStream(literalOutput);
      expr->printConstExprValue(&OutputStream, nullptr);
      if (!literalOutput.empty()) {
        return literalOutput;
      }
      break;
    }

    case ExprKind::StringLiteral: {
      auto stringLiteralExpression = cast<StringLiteralExpr>(expr);
      std::string literalOutput;
      llvm::raw_string_ostream OutputStream(literalOutput);
      OutputStream << stringLiteralExpression->getValue();
      return literalOutput;
    }

    default:
      break;
    }
  }
  return None;
}

static std::shared_ptr<CompileTimeValue> extractCompileTimeValue(Expr *expr) {
  if (expr) {
    switch (expr->getKind()) {
    case ExprKind::BooleanLiteral:
    case ExprKind::FloatLiteral:
    case ExprKind::IntegerLiteral:
    case ExprKind::NilLiteral:
    case ExprKind::StringLiteral: {
      auto rawLiteral = extractRawLiteral(expr);
      if (rawLiteral.has_value()) {
        return std::make_shared<RawLiteralValue>(rawLiteral.value());
      }

      break;
    }

    case ExprKind::Array: {
      auto arrayExpr = cast<ArrayExpr>(expr);
      std::vector<std::shared_ptr<CompileTimeValue>> elementValues;
      for (const auto elementExpr : arrayExpr->getElements()) {
        elementValues.push_back(extractCompileTimeValue(elementExpr));
      }
      return std::make_shared<ArrayValue>(elementValues);
    }

    case ExprKind::Dictionary: {
      auto dictionaryExpr = cast<DictionaryExpr>(expr);
      std::vector<std::shared_ptr<TupleValue>> tuples;
      for (auto elementExpr : dictionaryExpr->getElements()) {
        auto elementValue = extractCompileTimeValue(elementExpr);
        if (isa<TupleValue>(elementValue.get())) {
          tuples.push_back(std::static_pointer_cast<TupleValue>(elementValue));
        }
      }
      return std::make_shared<DictionaryValue>(tuples);
    }

    case ExprKind::Tuple: {
      auto tupleExpr = cast<TupleExpr>(expr);

      std::vector<TupleElement> elements;
      if (tupleExpr->hasElementNames()) {
        for (auto pair : llvm::zip(tupleExpr->getElements(),
                                   tupleExpr->getElementNames())) {
          auto elementExpr = std::get<0>(pair);
          auto elementName = std::get<1>(pair);

          Optional<std::string> label =
              elementName.empty()
                  ? Optional<std::string>()
                  : Optional<std::string>(elementName.str().str());

          elements.push_back({label, elementExpr->getType(),
                              extractCompileTimeValue(elementExpr)});
        }
      } else {
        for (auto elementExpr : tupleExpr->getElements()) {
          elements.push_back({Optional<std::string>(), elementExpr->getType(),
                              extractCompileTimeValue(elementExpr)});
        }
      }
      return std::make_shared<TupleValue>(elements);
    }

    case ExprKind::Call: {
      auto callExpr = cast<CallExpr>(expr);
      if (callExpr->getFn()->getKind() == ExprKind::ConstructorRefCall) {
        std::vector<FunctionParameter> parameters =
            extractFunctionArguments(callExpr->getArgs());
        return std::make_shared<InitCallValue>(callExpr->getType(), parameters);
      }

      if (callExpr->getFn()->getKind() == ExprKind::DotSyntaxCall) {
        auto dotSyntaxCallExpr = cast<DotSyntaxCallExpr>(callExpr->getFn());
        auto fn = dotSyntaxCallExpr->getFn();
        if (fn->getKind() == ExprKind::DeclRef) {
          auto declRefExpr = cast<DeclRefExpr>(fn);
          auto caseName =
              declRefExpr->getDecl()->getName().getBaseIdentifier().str().str();

          std::vector<FunctionParameter> parameters =
              extractFunctionArguments(callExpr->getArgs());
          return std::make_shared<EnumValue>(caseName, parameters);
        }
      }

      break;
    }

    case ExprKind::DotSyntaxCall: {
      auto dotSyntaxCallExpr = cast<DotSyntaxCallExpr>(expr);
      auto fn = dotSyntaxCallExpr->getFn();
      if (fn->getKind() == ExprKind::DeclRef) {
        auto declRefExpr = cast<DeclRefExpr>(fn);
        auto caseName =
            declRefExpr->getDecl()->getName().getBaseIdentifier().str().str();
        return std::make_shared<EnumValue>(caseName, None);
      }

      break;
    }

    case ExprKind::Erasure: {
      auto erasureExpr = cast<ErasureExpr>(expr);
      return extractCompileTimeValue(erasureExpr->getSubExpr());
    }

    case ExprKind::Paren: {
      auto parenExpr = cast<ParenExpr>(expr);
      return extractCompileTimeValue(parenExpr->getSubExpr());
    }

    case ExprKind::PropertyWrapperValuePlaceholder: {
      auto placeholderExpr = cast<PropertyWrapperValuePlaceholderExpr>(expr);
      return extractCompileTimeValue(
          placeholderExpr->getOriginalWrappedValue());
    }

    default: {
      break;
    }
    }
  }

  return std::make_shared<RuntimeValue>();
}

static std::vector<CustomAttrValue>
extractCustomAttrValues(VarDecl *propertyDecl) {
  std::vector<CustomAttrValue> customAttrValues;

  for (auto *propertyWrapper : propertyDecl->getAttachedPropertyWrappers()) {
    std::vector<FunctionParameter> parameters;

    if (const auto *args = propertyWrapper->getArgs()) {
      for (auto arg : *args) {
        const auto label = arg.getLabel().str().str();
        auto argExpr = arg.getExpr();

        if (auto defaultArgument = dyn_cast<DefaultArgumentExpr>(argExpr)) {
          auto *decl = defaultArgument->getParamDecl();
          if (decl->hasDefaultExpr()) {
            argExpr = decl->getTypeCheckedDefaultExpr();
          }
        }
        parameters.push_back(
            {label, argExpr->getType(), extractCompileTimeValue(argExpr)});
      }
    }

    customAttrValues.push_back({propertyWrapper, parameters});
  }

  return customAttrValues;
}

static ConstValueTypePropertyInfo
extractTypePropertyInfo(VarDecl *propertyDecl) {
  if (const auto binding = propertyDecl->getParentPatternBinding()) {
    if (const auto originalInit = binding->getInit(0)) {
      if (propertyDecl->hasAttachedPropertyWrapper()) {
        return {propertyDecl, extractCompileTimeValue(originalInit),
                extractCustomAttrValues(propertyDecl)};
      }

      return {propertyDecl, extractCompileTimeValue(originalInit)};
    }
  }

  if (auto accessorDecl = propertyDecl->getAccessor(AccessorKind::Get)) {
    auto node = accessorDecl->getTypecheckedBody()->getFirstElement();
    if (auto *stmt = node.dyn_cast<Stmt *>()) {
      if (stmt->getKind() == StmtKind::Return) {
        return {propertyDecl,
                extractCompileTimeValue(cast<ReturnStmt>(stmt)->getResult())};
      }
    }
  }

  return {propertyDecl, std::make_shared<RuntimeValue>()};
}

llvm::Optional<std::vector<EnumElementDeclValue>>
extractEnumCases(NominalTypeDecl *Decl) {
  if (Decl->getKind() == DeclKind::Enum) {
    std::vector<EnumElementDeclValue> Elements;
    for (EnumCaseDecl *ECD : cast<EnumDecl>(Decl)->getAllCases()) {
      for (EnumElementDecl *EED : ECD->getElements()) {
        std::string Name = EED->getNameStr().str();
        llvm::Optional<std::string> RawValue =
            extractRawLiteral(EED->getRawValueExpr());

        std::vector<EnumElementParameterValue> Parameters;
        if (const ParameterList *Params = EED->getParameterList()) {
          for (const ParamDecl *Parameter : Params->getArray()) {
            Optional<std::string> Label =
                Parameter->getParameterName().empty()
                    ? Optional<std::string>()
                    : Optional<std::string>(
                          Parameter->getParameterName().str().str());

            Parameters.push_back({Label, Parameter->getType()});
          }
        }

        if (Parameters.empty()) {
          Elements.push_back({Name, RawValue, None});
        } else {
          Elements.push_back({Name, RawValue, Parameters});
        }
      }
    }
    return Elements;
  }

  return None;
}

ConstValueTypeInfo
ConstantValueInfoRequest::evaluate(Evaluator &Evaluator,
                                   NominalTypeDecl *Decl) const {
  // Use 'getStoredProperties' to get lowered lazy and wrapped properties
  auto StoredProperties = Decl->getStoredProperties();
  std::unordered_set<VarDecl *> StoredPropertiesSet(StoredProperties.begin(),
                                                    StoredProperties.end());

  std::vector<ConstValueTypePropertyInfo> Properties;
  for (auto Property : StoredProperties) {
    Properties.push_back(extractTypePropertyInfo(Property));
  }

  for (auto Member : Decl->getMembers()) {
    auto *VD = dyn_cast<VarDecl>(Member);
    // Ignore plain stored properties collected above,
    // instead gather up remaining static and computed properties.
    if (!VD || StoredPropertiesSet.count(VD))
      continue;
    Properties.push_back(extractTypePropertyInfo(VD));
  }

  for (auto Extension: Decl->getExtensions()) {
    for (auto Member : Extension->getMembers()) {
      if (auto *VD = dyn_cast<VarDecl>(Member)) {
        Properties.push_back(extractTypePropertyInfo(VD));
      }
    }
  }

  return ConstValueTypeInfo{Decl, Properties, extractEnumCases(Decl)};
}

std::vector<ConstValueTypeInfo>
gatherConstValuesForModule(const std::unordered_set<std::string> &Protocols,
                           ModuleDecl *Module) {
  std::vector<ConstValueTypeInfo> Result;

  std::vector<NominalTypeDecl *> ConformanceDecls;
  NominalTypeConformanceCollector ConformanceCollector(Protocols,
                                                       ConformanceDecls);
  Module->walk(ConformanceCollector);
  for (auto *CD : ConformanceDecls)
    Result.emplace_back(evaluateOrDefault(CD->getASTContext().evaluator,
                                          ConstantValueInfoRequest{CD}, {}));
  return Result;
}

std::vector<ConstValueTypeInfo>
gatherConstValuesForPrimary(const std::unordered_set<std::string> &Protocols,
                            const SourceFile *SF) {
  std::vector<ConstValueTypeInfo> Result;

  std::vector<NominalTypeDecl *> ConformanceDecls;
  NominalTypeConformanceCollector ConformanceCollector(Protocols,
                                                       ConformanceDecls);
  for (auto D : SF->getTopLevelDecls())
    D->walk(ConformanceCollector);

  for (auto *CD : ConformanceDecls)
    Result.emplace_back(evaluateOrDefault(CD->getASTContext().evaluator,
                                          ConstantValueInfoRequest{CD}, {}));
  return Result;
}

void writeLocationInformation(llvm::json::OStream &JSON, SourceLoc Loc,
                              const ASTContext &ctx) {
  if (Loc.isInvalid())
    return;

  JSON.attribute("file", ctx.SourceMgr.getDisplayNameForLoc(Loc));
  JSON.attribute("line",
                 ctx.SourceMgr.getPresumedLineAndColumnForLoc(Loc).first);
}

void writeValue(llvm::json::OStream &JSON,
                std::shared_ptr<CompileTimeValue> Value) {
  auto value = Value.get();
  switch (value->getKind()) {
  case CompileTimeValue::ValueKind::RawLiteral: {
    JSON.attribute("valueKind", "RawLiteral");
    JSON.attribute("value", cast<RawLiteralValue>(value)->getValue());
    break;
  }

  case CompileTimeValue::ValueKind::InitCall: {
    auto initCallValue = cast<InitCallValue>(value);

    JSON.attribute("valueKind", "InitCall");
    JSON.attributeObject("value", [&]() {
      JSON.attribute("type",
                     toFullyQualifiedTypeNameString(initCallValue->getType()));
      JSON.attributeArray("arguments", [&] {
        for (auto FP : initCallValue->getParameters()) {
          JSON.object([&] {
            JSON.attribute("label", FP.Label);
            JSON.attribute("type", toFullyQualifiedTypeNameString(FP.Type));
            writeValue(JSON, FP.Value);
          });
        }
      });
    });
    break;
  }

  case CompileTimeValue::ValueKind::Tuple: {
    auto tupleValue = cast<TupleValue>(value);

    JSON.attribute("valueKind", "Tuple");
    JSON.attributeArray("value", [&] {
      for (auto TV : tupleValue->getElements()) {
        JSON.object([&] {
          if (auto Label = TV.Label) {
            JSON.attribute("label", Label);
          }
          JSON.attribute("type", toFullyQualifiedTypeNameString(TV.Type));
          writeValue(JSON, TV.Value);
        });
      }
    });
    break;
  }

  case CompileTimeValue::ValueKind::Builder: {
    JSON.attribute("valueKind", "Builder");
    break;
  }

  case CompileTimeValue::ValueKind::Dictionary: {
    JSON.attribute("valueKind", "Dictionary");
    JSON.attributeArray("value", [&] {
      for (auto tupleValue : cast<DictionaryValue>(value)->getElements()) {
        auto tupleElements = tupleValue.get()->getElements();
        JSON.object([&] {
          JSON.attributeObject(
              "key", [&] { writeValue(JSON, tupleElements[0].Value); });
          JSON.attributeObject(
              "value", [&] { writeValue(JSON, tupleElements[1].Value); });
        });
      }
    });
    break;
  }

  case CompileTimeValue::ValueKind::Array: {
    auto arrayValue = cast<ArrayValue>(value);

    JSON.attribute("valueKind", "Array");
    JSON.attributeArray("value", [&] {
      for (auto CTP : arrayValue->getElements()) {
        JSON.object([&] { writeValue(JSON, CTP); });
      }
    });
    break;
  }

  case CompileTimeValue::ValueKind::Enum: {
    auto enumValue = cast<EnumValue>(value);
    JSON.attribute("valueKind", "Enum");
    JSON.attributeObject("value", [&]() {
      JSON.attribute("name", enumValue->getIdentifier());
      if (enumValue->getParameters().has_value()) {
        auto params = enumValue->getParameters().value();
        JSON.attributeArray("arguments", [&] {
          for (auto FP : params) {
            JSON.object([&] {
              JSON.attribute("label", FP.Label);
              JSON.attribute("type", toFullyQualifiedTypeNameString(FP.Type));
              writeValue(JSON, FP.Value);
            });
          }
        });
      }
    });
    break;
  }

  case CompileTimeValue::ValueKind::Runtime: {
    JSON.attribute("valueKind", "Runtime");
    break;
  }
  }
}

void writePropertyWrapperAttributes(
    llvm::json::OStream &JSON,
    llvm::Optional<std::vector<CustomAttrValue>> PropertyWrappers,
    const ASTContext &ctx) {
  if (!PropertyWrappers.has_value()) {
    return;
  }

  JSON.attributeArray("propertyWrappers", [&] {
    for (auto PW : PropertyWrappers.value()) {
      JSON.object([&] {
        JSON.attribute("type",
                       toFullyQualifiedTypeNameString(PW.Attr->getType()));
        writeLocationInformation(JSON, PW.Attr->getLocation(), ctx);
        JSON.attributeArray("arguments", [&] {
          for (auto FP : PW.Parameters) {
            JSON.object([&] {
              JSON.attribute("label", FP.Label);
              JSON.attribute("type", toFullyQualifiedTypeNameString(FP.Type));
              writeValue(JSON, FP.Value);
            });
          }
        });
      });
    }
  });
}

void writeEnumCases(
    llvm::json::OStream &JSON,
    llvm::Optional<std::vector<EnumElementDeclValue>> EnumElements) {
  if (!EnumElements.has_value()) {
    return;
  }

  JSON.attributeArray("cases", [&] {
    for (const auto &Case : EnumElements.value()) {
      JSON.object([&] {
        JSON.attribute("name", Case.Name);
        if (Case.RawValue.has_value()) {
          JSON.attribute("rawValue", Case.RawValue.value());
        }
        if (Case.Parameters.has_value()) {
          JSON.attributeArray("parameters", [&] {
            for (const auto &Parameter : Case.Parameters.value()) {
              JSON.object([&] {
                if (auto Label = Parameter.Label) {
                  JSON.attribute("label", Label);
                }
                JSON.attribute("type",
                               toFullyQualifiedTypeNameString(Parameter.Type));
              });
            }
          });
        }
      });
    }
  });
}

void writeResultBuilderInformation(llvm::json::OStream &JSON,
                                   const swift::NominalTypeDecl *TypeDecl,
                                   const swift::VarDecl *VarDecl) {
  if (auto *attr = VarDecl->getAttachedResultBuilder()) {
    JSON.attributeObject("resultBuilder", [&] {
      JSON.attribute("type", toFullyQualifiedTypeNameString(attr->getType()));
    });

    return;
  }

  for (ProtocolDecl *Decl :
       TypeDecl->getLocalProtocols(ConformanceLookupKind::All)) {
    for (auto Member : Decl->getMembers()) {
      if (auto *VD = dyn_cast<swift::VarDecl>(Member)) {
        if (VD->getName() != VarDecl->getName())
          continue;

        if (auto *attr = VD->getAttachedResultBuilder()) {
          JSON.attributeObject("resultBuilder", [&] {
            JSON.attribute("type",
                           toFullyQualifiedTypeNameString(attr->getType()));
          });
        }

        return;
      }
    }
  }
}

void writeAttrInformation(llvm::json::OStream &JSON,
                          const DeclAttributes &Attrs) {
  auto availableAttr = Attrs.getAttributes<AvailableAttr>();
  if (availableAttr.empty())
    return;

  JSON.attributeArray("availabilityAttributes", [&] {
    for (const AvailableAttr *attr : availableAttr) {
      JSON.object([&] {
        if (!attr->platformString().empty())
          JSON.attribute("platform", attr->platformString());

        if (!attr->Message.empty())
          JSON.attribute("message", attr->Message);

        if (!attr->Rename.empty())
          JSON.attribute("rename", attr->Rename);

        if (attr->Introduced.has_value())
          JSON.attribute("introducedVersion",
                         attr->Introduced.value().getAsString());

        if (attr->Deprecated.has_value())
          JSON.attribute("deprecatedVersion",
                         attr->Deprecated.value().getAsString());

        if (attr->Obsoleted.has_value())
          JSON.attribute("obsoletedVersion",
                         attr->Obsoleted.value().getAsString());

        JSON.attribute("isUnavailable", attr->isUnconditionallyUnavailable());
        JSON.attribute("isDeprecated", attr->isUnconditionallyDeprecated());
      });
    }
  });
}

bool writeAsJSONToFile(const std::vector<ConstValueTypeInfo> &ConstValueInfos,
                       llvm::raw_fd_ostream &OS) {
  llvm::json::OStream JSON(OS, 2);
  JSON.array([&] {
    for (const auto &TypeInfo : ConstValueInfos) {
      JSON.object([&] {
        const auto *TypeDecl = TypeInfo.TypeDecl;
        JSON.attribute("typeName", toFullyQualifiedTypeNameString(
                                       TypeDecl->getDeclaredInterfaceType()));
        JSON.attribute(
            "kind",
            TypeDecl->getDescriptiveKindName(TypeDecl->getDescriptiveKind())
                .str());
        writeLocationInformation(
            JSON, extractNearestSourceLoc(TypeDecl->getInnermostDeclContext()),
            TypeDecl->getInnermostDeclContext()->getASTContext());
        JSON.attributeArray("properties", [&] {
          for (const auto &PropertyInfo : TypeInfo.Properties) {
            JSON.object([&] {
              const auto *decl = PropertyInfo.VarDecl;
              JSON.attribute("label", decl->getName().str().str());
              JSON.attribute("type",
                             toFullyQualifiedTypeNameString(decl->getType()));
              JSON.attribute("isStatic", decl->isStatic() ? "true" : "false");
              JSON.attribute("isComputed",
                             !decl->hasStorage() ? "true" : "false");
              writeLocationInformation(JSON, decl->getLoc(),
                                       decl->getDeclContext()->getASTContext());
              writeValue(JSON, PropertyInfo.Value);
              writePropertyWrapperAttributes(
                  JSON, PropertyInfo.PropertyWrappers, decl->getASTContext());
              writeResultBuilderInformation(JSON, TypeDecl, decl);
              writeAttrInformation(JSON, decl->getAttrs());
            });
          }
        });
        writeEnumCases(JSON, TypeInfo.EnumElements);
        writeAttrInformation(JSON, TypeDecl->getAttrs());
      });
    }
  });
  JSON.flush();
  return false;
}

} // namespace swift

#define SWIFT_TYPEID_ZONE ConstExtract
#define SWIFT_TYPEID_HEADER "swift/ConstExtract/ConstExtractTypeIDZone.def"
#include "swift/Basic/ImplementTypeIDZone.h"
#undef SWIFT_TYPEID_ZONE
#undef SWIFT_TYPEID_HEADER

// Define request evaluation functions for each of the name lookup requests.
static AbstractRequestFunction *constExtractRequestFunctions[] = {
#define SWIFT_REQUEST(Zone, Name, Sig, Caching, LocOptions)                    \
  reinterpret_cast<AbstractRequestFunction *>(&Name::evaluateRequest),
#include "swift/ConstExtract/ConstExtractTypeIDZone.def"
#undef SWIFT_REQUEST
};

void swift::registerConstExtractRequestFunctions(Evaluator &evaluator) {
  evaluator.registerRequestFunctions(Zone::ConstExtract,
                                     constExtractRequestFunctions);
}
