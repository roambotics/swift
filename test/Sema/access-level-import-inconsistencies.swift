/// Import inconsistencies.
///
/// Swift 5 case, with slow adoption of access level on imports.
/// Report default imports if any other import of the same module
/// has an access level below public (the default).
///
/// Swift 6 case, with default imports as internal.
/// Don't report any mismatch.

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// REQUIRES: asserts

/// Build the library.
// RUN: %target-swift-frontend -emit-module %t/Lib.swift -o %t

/// Check diagnostics.

//--- Lib.swift
public struct LibType {}

// RUN: %target-swift-frontend -typecheck %t/OneFile_AllExplicit.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify
//--- OneFile_AllExplicit.swift
public import Lib
package import Lib
internal import Lib
fileprivate import Lib
private import Lib

// RUN: %target-swift-frontend -typecheck %t/ManyFiles_AllExplicit_File?.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify
//--- ManyFiles_AllExplicit_FileA.swift
public import Lib
//--- ManyFiles_AllExplicit_FileB.swift
package import Lib
//--- ManyFiles_AllExplicit_FileC.swift
internal import Lib
//--- ManyFiles_AllExplicit_FileD.swift
fileprivate import Lib
//--- ManyFiles_AllExplicit_FileE.swift
private import Lib

// RUN: %target-swift-frontend -typecheck %t/ManyFiles_ImplicitVsInternal_FileB.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify \
// RUN:   -primary-file %t/ManyFiles_ImplicitVsInternal_FileA.swift
//--- ManyFiles_ImplicitVsInternal_FileA.swift
import Lib // expected-error {{ambiguous implicit access level for import of 'Lib'; it is imported as 'internal' elsewhere}}
//--- ManyFiles_ImplicitVsInternal_FileB.swift
internal import Lib // expected-note {{imported 'internal' here}}

// RUN: %target-swift-frontend -typecheck %t/ManyFiles_ImplicitVsPackage_FileB.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify \
// RUN:   -primary-file %t/ManyFiles_ImplicitVsPackage_FileA.swift
//--- ManyFiles_ImplicitVsPackage_FileA.swift
import Lib // expected-error {{ambiguous implicit access level for import of 'Lib'; it is imported as 'package' elsewhere}}
//--- ManyFiles_ImplicitVsPackage_FileB.swift
package import Lib // expected-note {{imported 'package' here}} @:1

// RUN: %target-swift-frontend -typecheck %t/ManyFiles_AmbiguitySwift6_File?.swift -I %t \
// RUN:   -enable-experimental-feature AccessLevelOnImport -verify -swift-version 6
//--- ManyFiles_AmbiguitySwift6_FileA.swift
import Lib
//--- ManyFiles_AmbiguitySwift6_FileB.swift
internal import Lib
