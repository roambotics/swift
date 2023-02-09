//===--- GenPack.h - Swift IR Generation For Variadic Generics --*- C++ -*-===//
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
//
//  This file implements IR generation for type and value packs in Swift.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_IRGEN_GENPACK_H
#define SWIFT_IRGEN_GENPACK_H

#include "swift/AST/Types.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"

namespace llvm {

class Value;

} // end namespace llvm

namespace swift {

namespace irgen {
class Address;
class IRGenFunction;
class DynamicMetadataRequest;
class MetadataResponse;
class StackAddress;

MetadataResponse
emitPackArchetypeMetadataRef(IRGenFunction &IGF,
                             CanPackArchetypeType type,
                             DynamicMetadataRequest request);

StackAddress
emitTypeMetadataPack(IRGenFunction &IGF,
                     CanPackType packType,
                     DynamicMetadataRequest request);

MetadataResponse
emitTypeMetadataPackRef(IRGenFunction &IGF,
                        CanPackType packType,
                        DynamicMetadataRequest request);

llvm::Value *
emitTypeMetadataPackElementRef(IRGenFunction &IGF, CanPackType packType,
                               ArrayRef<ProtocolDecl *> protocols,
                               llvm::Value *index,
                               DynamicMetadataRequest request,
                               llvm::SmallVectorImpl<llvm::Value *> &wtables);

void cleanupTypeMetadataPack(IRGenFunction &IGF,
                             StackAddress pack,
                             Optional<unsigned> elementCount);

StackAddress emitWitnessTablePack(IRGenFunction &IGF, CanPackType packType,
                                  PackConformance *conformance);

llvm::Value *emitWitnessTablePackRef(IRGenFunction &IGF, CanPackType packType,
                                     PackConformance *conformance);

void cleanupWitnessTablePack(IRGenFunction &IGF, StackAddress pack,
                             Optional<unsigned> elementCount);

/// Emit the dynamic index of a particular structural component
/// of the given pack type.  If the component is a pack expansion, this
/// is the index of the first element of the pack (or where it would be
/// if it had any elements).
llvm::Value *emitIndexOfStructuralPackComponent(IRGenFunction &IGF,
                                                CanPackType packType,
                                                unsigned componentIndex);

/// Emit the address that stores the given pack element.
///
/// For indirect packs, note that this is the address of the pack
/// array element, not the address stored in the pack array element.
Address emitStorageAddressOfPackElement(IRGenFunction &IGF,
                                        Address pack, llvm::Value *index,
                                        SILType elementType);

} // end namespace irgen
} // end namespace swift

#endif
