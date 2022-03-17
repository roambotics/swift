// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) %s -typecheck -emit-cxx-header-path %t/empty.h
// RUN: %FileCheck %s < %t/empty.h

// RUN: %check-cxx-header-in-clang -std=c++14 %t/empty.h
// RUN: %check-cxx-header-in-clang -std=c++17 %t/empty.h

// CHECK-NOT: @import Swift;
// CHECK-NOT: IBSegueAction

// CHECK-LABEL: #ifndef EMPTY_SWIFT_H
// CHECK-NEXT:  #define EMPTY_SWIFT_H

// CHECK-LABEL: #if !defined(__has_include)
// CHECK-NEXT: # define __has_include(x) 0
// CHECK-NEXT: #endif

// CHECK-LABEL: #if !defined(__has_attribute)
// CHECK-NEXT: # define __has_attribute(x) 0
// CHECK-NEXT: #endif

// CHECK-LABEL: #if !defined(__has_feature)
// CHECK-NEXT: # define __has_feature(x) 0
// CHECK-NEXT: #endif

// CHECK-LABEL: #if !defined(__has_warning)
// CHECK-NEXT: # define __has_warning(x) 0
// CHECK-NEXT: #endif

// CHECK-LABEL: #if defined(__OBJC__)
// CHECK-NEXT:  #include <Foundation/Foundation.h>
// CHECK-NEXT:  #endif
// CHECK-NEXT:  #if defined(__cplusplus)
// CHECK-NEXT:  #include <cstdint>
// CHECK-NEXT:  #include <cstddef>
// CHECK-NEXT:  #include <cstdbool>
// CHECK-NEXT:  #else
// CHECK-NEXT:  #include <stdint.h>
// CHECK-NEXT:  #include <stddef.h>
// CHECK-NEXT:  #include <stdbool.h>
// CHECK-NEXT:  #endif

// CHECK-LABEL: !defined(SWIFT_TYPEDEFS)
// CHECK-NEXT:  # define SWIFT_TYPEDEFS 1
// CHECK:       typedef float swift_float2  __attribute__((__ext_vector_type__(2)));
// CHECK-NEXT:  typedef float swift_float3  __attribute__((__ext_vector_type__(3)));
// CHECK-NEXT:  typedef float swift_float4  __attribute__((__ext_vector_type__(4)));
// CHECK-NEXT:  typedef double swift_double2  __attribute__((__ext_vector_type__(2)));
// CHECK-NEXT:  typedef double swift_double3  __attribute__((__ext_vector_type__(3)));
// CHECK-NEXT:  typedef double swift_double4  __attribute__((__ext_vector_type__(4)));
// CHECK-NEXT:  typedef int swift_int2  __attribute__((__ext_vector_type__(2)));
// CHECK-NEXT:  typedef int swift_int3  __attribute__((__ext_vector_type__(3)));
// CHECK-NEXT:  typedef int swift_int4  __attribute__((__ext_vector_type__(4)));
// CHECK-NEXT:  typedef unsigned int swift_uint2  __attribute__((__ext_vector_type__(2)));
// CHECK-NEXT:  typedef unsigned int swift_uint3  __attribute__((__ext_vector_type__(3)));
// CHECK-NEXT:  typedef unsigned int swift_uint4  __attribute__((__ext_vector_type__(4)));

// CHECK: # define SWIFT_METATYPE(X)
// CHECK: # define SWIFT_CLASS
// CHECK: # define SWIFT_CLASS_NAMED
// CHECK: # define SWIFT_PROTOCOL
// CHECK: # define SWIFT_PROTOCOL_NAMED
// CHECK: # define SWIFT_EXTENSION(M)
// CHECK: # define OBJC_DESIGNATED_INITIALIZER

// CHECK-LABEL: namespace empty {
// CHECK: } // namespace empty

// CHECK-NOT: @
