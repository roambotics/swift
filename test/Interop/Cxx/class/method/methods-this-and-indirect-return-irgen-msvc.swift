// RUN: %target-swift-emit-irgen -I %S/Inputs -enable-experimental-cxx-interop %s | %FileCheck %s -check-prefix=CHECK -check-prefix=CHECK-%target-cpu

// REQUIRES: OS=windows-msvc

import Methods

public func use() -> CInt {
    var instance = HasMethods()
    let result = instance.nonConstPassThroughAsWrapper(42)
    return result.value
}

// CHECK: %[[instance:.*]] = alloca %TSo10HasMethodsV
// CHECK: %[[result:.*]] = alloca %TSo19NonTrivialInWrapperV
// CHECK: call void @"?nonConstPassThroughAsWrapper@HasMethods@@QEAA?AUNonTrivialInWrapper@@H@Z"(ptr %[[instance]], ptr noalias sret(%TSo19NonTrivialInWrapperV) %[[result]], i32 42)

// CHECK-x86_64: define {{.*}} void @"?nonConstPassThroughAsWrapper@HasMethods@@QEAA?AUNonTrivialInWrapper@@H@Z"(ptr {{.*}} %{{.*}}, ptr noalias sret(%struct.NonTrivialInWrapper) {{.*}} %{{.*}}, i32 noundef %{{.*}})
// CHECK-aarch64: define {{.*}} void @"?nonConstPassThroughAsWrapper@HasMethods@@QEAA?AUNonTrivialInWrapper@@H@Z"(ptr {{.*}} %{{.*}}, ptr inreg noalias sret(%struct.NonTrivialInWrapper) {{.*}} %{{.*}}, i32 noundef %{{.*}})
