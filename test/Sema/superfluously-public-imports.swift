// RUN: %empty-directory(%t)
// RUN: split-file --leading-lines %s %t
// REQUIRES: asserts

/// Build the libraries.
// RUN: %target-swift-frontend -emit-module %t/DepUsedFromInlinableCode.swift -o %t
// RUN: %target-swift-frontend -emit-module %t/DepUsedInSignature.swift -o %t
// RUN: %target-swift-frontend -emit-module %t/Exportee.swift -o %t
// RUN: %target-swift-frontend -emit-module %t/Exporter.swift -o %t -I %t
// RUN: %target-swift-frontend -emit-module %t/ConformanceBaseTypes.swift -o %t
// RUN: %target-swift-frontend -emit-module %t/ConformanceDefinition.swift -o %t -I %t
// RUN: %target-swift-frontend -emit-module %t/AliasesBase.swift -o %t
// RUN: %target-swift-frontend -emit-module %t/Aliases.swift -o %t -I %t
// RUN: %target-swift-frontend -emit-module %t/UnusedImport.swift -o %t -I %t
// RUN: %target-swift-frontend -emit-module %t/UnusedPackageImport.swift -o %t -I %t
// RUN: %target-swift-frontend -emit-module %t/ImportNotUseFromAPI.swift -o %t -I %t
// RUN: %target-swift-frontend -emit-module %t/ImportUsedInPackage.swift -o %t -I %t

/// Check diagnostics.
// RUN: %target-swift-frontend -typecheck %t/Client.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify \
// RUN:   -package-name pkg -Rmodule-api-import -swift-version 6
// RUN: %target-swift-frontend -typecheck %t/Client_Swift5.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify \
// RUN:   -swift-version 5

//--- DepUsedFromInlinableCode.swift
public struct TypeUsedFromInlinableCode {}
public func funcUsedFromInlinableCode() {}

public func funcUsedFromDefaultValue() -> Int { 42 }

//--- DepUsedInSignature.swift
public struct TypeUsedInSignature {}
public protocol ComposedProtoA {}
public protocol ComposedProtoB {}

//--- Exportee.swift
public struct ExportedType {}

//--- Exporter.swift
@_exported import Exportee

//--- ConformanceBaseTypes.swift
public protocol Proto {}
public struct ConformingType {
    public init () {}
}

//--- ConformanceDefinition.swift
import ConformanceBaseTypes
extension ConformingType : Proto  {}

//--- AliasesBase.swift
open class Clazz {}

//--- Aliases.swift
import AliasesBase
public typealias ClazzAlias = Clazz

//--- UnusedImport.swift

//--- UnusedPackageImport.swift

//--- ImportNotUseFromAPI.swift
public struct NotAnAPIType {}
public func notAnAPIFunc() -> NotAnAPIType { return NotAnAPIType() }

//--- ImportUsedInPackage.swift
public struct PackageType {}
public func packageFunc() -> PackageType { return PackageType() }

//--- Client_Swift5.swift
/// No diagnostics should be raised on the implicit access level.
import UnusedImport // expected-error {{ambiguous implicit access level for import of 'UnusedImport'; it is imported as 'public' elsewhere}}
public import UnusedImport // expected-warning {{public import of 'UnusedImport' was not used in public declarations or inlinable code}} {{1-7=internal}}
// expected-note @-1 {{imported 'public' here}}

//--- Client.swift
public import DepUsedFromInlinableCode
public import DepUsedInSignature
public import Exporter
public import ConformanceBaseTypes
public import ConformanceDefinition
public import AliasesBase
public import Aliases

public import UnusedImport // expected-warning {{public import of 'UnusedImport' was not used in public declarations or inlinable code}} {{1-8=}}
public import UnusedImport // expected-warning {{public import of 'UnusedImport' was not used in public declarations or inlinable code}} {{1-8=}}
package import UnusedImport // expected-warning {{package import of 'UnusedImport' was not used in package declarations}} {{1-9=}}

package import UnusedPackageImport // expected-warning {{package import of 'UnusedPackageImport' was not used in package declarations}} {{1-9=}}
public import ImportNotUseFromAPI // expected-warning {{public import of 'ImportNotUseFromAPI' was not used in public declarations or inlinable code}} {{1-8=}}
public import ImportUsedInPackage // expected-warning {{public import of 'ImportUsedInPackage' was not used in public declarations or inlinable code}} {{1-7=package}}

public func useInSignature(_ a: TypeUsedInSignature) {} // expected-remark {{struct 'TypeUsedInSignature' is imported via 'DepUsedInSignature'}}
public func exportedTypeUseInSignature(_ a: ExportedType) {} // expected-remark {{struct 'ExportedType' is imported via 'Exporter', which reexports definition from 'Exportee'}}

public func useInDefaultValue(_ a: Int = funcUsedFromDefaultValue()) {}
// expected-remark @-1 {{struct 'Int' is imported via 'Swift'}}
// expected-remark @-2 {{global function 'funcUsedFromDefaultValue()' is imported via 'DepUsedFromInlinableCode'}}

public func genericType(_ a: Array<TypeUsedInSignature>) {}
// expected-remark @-1 {{generic struct 'Array' is imported via 'Swift'}}
// expected-remark @-2 {{struct 'TypeUsedInSignature' is imported via 'DepUsedInSignature'}}

public func protocolComposition(_ a: any ComposedProtoA & ComposedProtoB) {}
// expected-remark @-1 {{protocol 'ComposedProtoA' is imported via 'DepUsedInSignature'}}
// expected-remark @-2 {{protocol 'ComposedProtoB' is imported via 'DepUsedInSignature'}}

public func useConformance(_ a: any Proto = ConformingType()) {}
// expected-remark @-1 {{protocol 'Proto' is imported via 'ConformanceBaseTypes'}}
// expected-remark @-2 {{conformance of 'ConformingType' to protocol 'Proto' used here is imported via 'ConformanceDefinition'}}
// expected-remark @-3 {{struct 'ConformingType' is imported via 'ConformanceBaseTypes'}}
// expected-remark @-4 {{initializer 'init()' is imported via 'ConformanceBaseTypes'}}

@usableFromInline internal func useInDefaultValue(_ a: TypeUsedInSignature) {} // expected-remark {{struct 'TypeUsedInSignature' is imported via 'DepUsedInSignature'}}

@inlinable
public func publicFuncUsesPrivate() {
  let _: TypeUsedFromInlinableCode // expected-remark {{struct 'TypeUsedFromInlinableCode' is imported via 'DepUsedFromInlinableCode'}}
  let _: ExportedType // expected-remark {{struct 'ExportedType' is imported via 'Exporter', which reexports definition from 'Exportee'}}
  funcUsedFromInlinableCode() // expected-remark {{global function 'funcUsedFromInlinableCode()' is imported via 'DepUsedFromInlinableCode'}}

  let _: Array<TypeUsedInSignature>
  // expected-remark @-1 {{generic struct 'Array' is imported via 'Swift'}}
  // expected-remark @-2 {{struct 'TypeUsedInSignature' is imported via 'DepUsedInSignature'}}

  let _: any ComposedProtoA & ComposedProtoB
  // expected-remark @-1 {{protocol 'ComposedProtoA' is imported via 'DepUsedInSignature'}}
  // expected-remark @-2 {{protocol 'ComposedProtoB' is imported via 'DepUsedInSignature'}}

  let _: any Proto = ConformingType()
  // expected-remark @-1 {{protocol 'Proto' is imported via 'ConformanceBaseTypes'}}
  // expected-remark @-2 {{conformance of 'ConformingType' to protocol 'Proto' used here is imported via 'ConformanceDefinition'}}
  // expected-remark @-3 {{struct 'ConformingType' is imported via 'ConformanceBaseTypes'}}
  // expected-remark @-4 {{initializer 'init()' is imported via 'ConformanceBaseTypes'}}

  let _: ClazzAlias
  // expected-remark @-1 {{type alias 'ClazzAlias' is imported via 'Aliases'}}
  // expected-remark @-2 2 {{typealias underlying type class 'Clazz' is imported via 'AliasesBase'}}
}

public struct Struct { // expected-remark {{implicitly used struct 'Int' is imported via 'Swift'}}
  public var propWithInferredIntType = 42
  public var propWithExplicitType: String = "Text" // expected-remark {{struct 'String' is imported via 'Swift'}}
}

public func publicFunction() {
    let _: NotAnAPIType = notAnAPIFunc()
}

internal func internalFunc(a: NotAnAPIType = notAnAPIFunc()) {}
func implicitlyInternalFunc(a: NotAnAPIType = notAnAPIFunc()) {}

// For package decls we only remark on types used in signatures, not for inlinable code.
package func packageFunc(a: PackageType = packageFunc()) {} // expected-remark {{struct 'PackageType' is imported via 'ImportUsedInPackage'}}
