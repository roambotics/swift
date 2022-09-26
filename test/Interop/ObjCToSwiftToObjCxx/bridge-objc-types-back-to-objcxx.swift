// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-frontend -typecheck %t/use-objc-types.swift -typecheck -module-name UseObjCTy -emit-clang-header-path %t/UseObjCTy.h -I %t -enable-experimental-cxx-interop -clang-header-expose-public-decls

// RUN: %FileCheck %s < %t/UseObjCTy.h

// FIXME: remove once https://github.com/apple/swift/pull/60971 lands.
// RUN: echo "#include \"header.h\"" > %t/full-header.h
// RUN: cat %t/UseObjCTy.h >> %t/full-header.h

// RUN: %target-interop-build-clangxx -std=gnu++20 -fobjc-arc -c -x objective-c++-header %t/full-header.h -o %t/o.o

// REQUIRES: objc_interop

//--- header.h

@interface ObjCKlass
-(ObjCKlass * _Nonnull) init;
@end

//--- module.modulemap
module ObjCTest {
    header "header.h"
}

//--- use-objc-types.swift
import ObjCTest

public func retObjClass() -> ObjCKlass {
    return ObjCKlass()
}

public func takeObjCClass(_ x: ObjCKlass) {
}

public func takeObjCClassInout(_ x: inout ObjCKlass) {
}

public func takeObjCClassNullable(_ x: ObjCKlass?) {
}

public func retObjClassNullable() -> ObjCKlass? {
    return nil
}

// CHECK: ObjCKlass *_Nonnull $s9UseObjCTy03retB5ClassSo0B6CKlassCyF(void) SWIFT_NOEXCEPT SWIFT_CALL;
// CHECK-NEXT: ObjCKlass *_Nullable $s9UseObjCTy03retB13ClassNullableSo0B6CKlassCSgyF(void) SWIFT_NOEXCEPT SWIFT_CALL;
// CHECK-NEXT: void $s9UseObjCTy04takeB6CClassyySo0B6CKlassCF(ObjCKlass *_Nonnull x) SWIFT_NOEXCEPT SWIFT_CALL;
// CHECK-NEXT: void $s9UseObjCTy04takeB11CClassInoutyySo0B6CKlassCzF(ObjCKlass *_Nonnull __strong * _Nonnull x) SWIFT_NOEXCEPT SWIFT_CALL;
// CHECK-NEXT: void $s9UseObjCTy04takeB14CClassNullableyySo0B6CKlassCSgF(ObjCKlass *_Nullable x) SWIFT_NOEXCEPT SWIFT_CALL;

// CHECK: inline ObjCKlass *_Nonnull retObjClass() noexcept SWIFT_WARN_UNUSED_RESULT {
// CHECK-NEXT: return (__bridge_transfer ObjCKlass *)(__bridge void *)_impl::$s9UseObjCTy03retB5ClassSo0B6CKlassCyF();

// CHECK: inline ObjCKlass *_Nullable retObjClassNullable() noexcept SWIFT_WARN_UNUSED_RESULT {
// CHECK-NEXT: return (__bridge_transfer ObjCKlass *)(__bridge void *)_impl::$s9UseObjCTy03retB13ClassNullableSo0B6CKlassCSgyF();

// CHECK: void takeObjCClass(ObjCKlass *_Nonnull x) noexcept {
// CHECK-NEXT: return _impl::$s9UseObjCTy04takeB6CClassyySo0B6CKlassCF(x);

// CHECK: inline void takeObjCClassInout(ObjCKlass *_Nonnull __strong & x) noexcept {
// CHECK-NEXT: return _impl::$s9UseObjCTy04takeB11CClassInoutyySo0B6CKlassCzF(&x);

// CHECK: inline void takeObjCClassNullable(ObjCKlass *_Nullable x) noexcept {
// CHECK-NEXT: return _impl::$s9UseObjCTy04takeB14CClassNullableyySo0B6CKlassCSgF(x);
