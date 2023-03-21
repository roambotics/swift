// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -enable-experimental-feature LayoutStringValueWitnesses -enable-type-layout -parse-stdlib -emit-module -emit-module-path=%t/layout_string_witnesses_types.swiftmodule %S/Inputs/layout_string_witnesses_types.swift
// RUN: %target-build-swift -Xfrontend -enable-experimental-feature -Xfrontend LayoutStringValueWitnesses -Xfrontend -enable-type-layout -Xfrontend -parse-stdlib -c -parse-as-library -o %t/layout_string_witnesses_types.o %S/Inputs/layout_string_witnesses_types.swift
// RUN: %target-swift-frontend -enable-experimental-feature LayoutStringValueWitnesses -enable-library-evolution -emit-module -emit-module-path=%t/layout_string_witnesses_types_resilient.swiftmodule %S/Inputs/layout_string_witnesses_types_resilient.swift
// RUN: %target-build-swift -g -Xfrontend -enable-experimental-feature -Xfrontend LayoutStringValueWitnesses -Xfrontend -enable-library-evolution -c -parse-as-library -o %t/layout_string_witnesses_types_resilient.o %S/Inputs/layout_string_witnesses_types_resilient.swift
// RUN: %target-build-swift -g -Xfrontend -enable-experimental-feature -Xfrontend LayoutStringValueWitnesses -Xfrontend -enable-type-layout -Xfrontend -parse-stdlib -module-name layout_string_witnesses_static %t/layout_string_witnesses_types.o %t/layout_string_witnesses_types_resilient.o -I %t -o %t/main %s
// RUN: %target-codesign %t/main
// RUN: %target-run %t/main | %FileCheck %s --check-prefix=CHECK -check-prefix=CHECK-%target-os

// REQUIRES: executable_test

// UNSUPPORTED: back_deployment_runtime

import Swift
import layout_string_witnesses_types
import layout_string_witnesses_types_resilient

class TestClass {
    init() {}

    deinit {
        print("TestClass deinitialized!")
    }
}

func testSimple() {
    let ptr = UnsafeMutablePointer<Simple>.allocate(capacity: 1)

    do {
        let x = Simple(x: 3, y: SimpleClass(x: 23), z: SimpleBig())
        testInit(ptr, to: x)
    }

    // CHECK: 3 - 23
    print("\(ptr.pointee.x) - \(ptr.pointee.y.x)")

    do {
        let y = Simple(x: 2, y: SimpleClass(x: 1), z: SimpleBig())

        // CHECK-NEXT: Before deinit
        print("Before deinit")
        
        // CHECK-NEXT: SimpleClass deinitialized!
        testAssign(ptr, from: y)
    }

    // CHECK-NEXT: 2 - 1
    print("\(ptr.pointee.x) - \(ptr.pointee.y.x)")

    // CHECK-NEXT: Before deinit
    print("Before deinit")
        

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)
    
    ptr.deallocate()
}

testSimple()

func testWeakNative() {
    let ptr = UnsafeMutablePointer<WeakNativeWrapper>.allocate(capacity: 1)

    do {
        let ref = SimpleClass(x: 2)
        withExtendedLifetime(ref) {
            testInit(ptr, to: WeakNativeWrapper(x: ref))

            guard let x = ptr.pointee.x else {
                fatalError("Weak reference prematurely destroyed")
            }

            // CHECK: value: 2
            print("value: \(x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-NEXT: Before deinit
            print("Before deinit")
        }
    }

    do {
        let ref = SimpleClass(x: 34)
        
        withExtendedLifetime(ref) {
            
            // CHECK-NEXT: SimpleClass deinitialized!
            testAssign(ptr, from: WeakNativeWrapper(x: ref))

            guard let x = ptr.pointee.x else {
                fatalError("Weak reference prematurely destroyed")
            }

            // CHECK-NEXT: value: 34
            print("value: \(x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-NEXT: Before deinit
            print("Before deinit")
        }
    }

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testWeakNative()

func testUnownedNative() {
    let ptr = UnsafeMutablePointer<UnownedNativeWrapper>.allocate(capacity: 1)

    do {
        let ref = SimpleClass(x: 2)
        withExtendedLifetime(ref) {
            testInit(ptr, to: UnownedNativeWrapper(x: ref))

            // CHECK: value: 2
            print("value: \(ptr.pointee.x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-NEXT: Before deinit
            print("Before deinit")
        }
    }

    do {
        let ref = SimpleClass(x: 34)
        
        withExtendedLifetime(ref) {
            // CHECK-NEXT: SimpleClass deinitialized!
            testAssign(ptr, from: UnownedNativeWrapper(x: ref))

            // CHECK-NEXT: value: 34
            print("value: \(ptr.pointee.x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-NEXT: Before deinit
            print("Before deinit")
        }
    }

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testUnownedNative()

func testClosure() {
    let ptr = UnsafeMutablePointer<ClosureWrapper>.allocate(capacity: 1)

    do {
        let ref = SimpleClass(x: 2)
        testInit(ptr, to: ClosureWrapper(f: { print("value: \(ref.x)") }))

        // CHECK: value: 2
        ptr.pointee.f()
    }

    do {
        let ref = SimpleClass(x: 34)
        // CHECK-NEXT: Before deinit
        print("Before deinit")

        // CHECK-NEXT: SimpleClass deinitialized!
        testAssign(ptr, from: ClosureWrapper(f: { print("value: \(ref.x)") }))

        // CHECK-NEXT: value: 34
        ptr.pointee.f()
    }

    // CHECK-NEXT: Before deinit
    print("Before deinit")

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testClosure()

class ClassWithSomeProtocol: SomeProtocol {
    deinit {
        print("ClassWithSomeProtocol deinitialized!")
    }
}

func testExistential() {
    let ptr = UnsafeMutablePointer<ExistentialWrapper>.allocate(capacity: 1)

    do {
        let x = ClassWithSomeProtocol()
        testInit(ptr, to: ExistentialWrapper(x: x))
    }

    do {
        let y = ClassWithSomeProtocol()

        // CHECK: Before deinit
        print("Before deinit")

        // CHECK-NEXT: ClassWithSomeProtocol deinitialized!
        testAssign(ptr, from: ExistentialWrapper(x: y))
    }

    // CHECK-NEXT: Before deinit
    print("Before deinit")

    // CHECK-NEXT: ClassWithSomeProtocol deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testExistential()

class ClassWithSomeClassProtocol: SomeClassProtocol {
    deinit {
        print("ClassWithSomeClassProtocol deinitialized!")
    }
}

func testExistentialReference() {
    let ptr = UnsafeMutablePointer<ExistentialRefWrapper>.allocate(capacity: 1)
    
    do {
        let x = ClassWithSomeClassProtocol()
        testInit(ptr, to: ExistentialRefWrapper(x: x))
    }

    do {
        let y = ClassWithSomeClassProtocol()

        // CHECK: Before deinit
        print("Before deinit")

        // CHECK-NEXT: ClassWithSomeClassProtocol deinitialized!
        testAssign(ptr, from: ExistentialRefWrapper(x: y))
    }

    // CHECK-NEXT: Before deinit
    print("Before deinit")

    // CHECK-NEXT: ClassWithSomeClassProtocol deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testExistentialReference()

func testMultiPayloadEnum() {
    let ptr = UnsafeMutablePointer<MultiPayloadEnumWrapper>.allocate(capacity: 1)

    do {
        let x = MultiPayloadEnumWrapper(x: .d, y: SimpleClass(x: 23))
        testInit(ptr, to: x)
    }

    do {
        let y = MultiPayloadEnumWrapper(x: .d, y: SimpleClass(x: 28))

        // CHECK: Before deinit
        print("Before deinit")
        
        // CHECK-NEXT: SimpleClass deinitialized!
        testAssign(ptr, from: y)
    }

    // CHECK-NEXT: Before deinit
    print("Before deinit")

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testMultiPayloadEnum()

func testNullableRefEnum() {
    let ptr = UnsafeMutablePointer<NullableRefEnum>.allocate(capacity: 1)

    do {
        let x = NullableRefEnum.nonEmpty(SimpleClass(x: 23))
        testInit(ptr, to: x)
    }

    do {
        let y = NullableRefEnum.nonEmpty(SimpleClass(x: 28))

        // CHECK: Before deinit
        print("Before deinit")

        // CHECK-NEXT: SimpleClass deinitialized!
        testAssign(ptr, from: y)
    }

    // CHECK-NEXT: Before deinit
    print("Before deinit")

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testNullableRefEnum()

func testForwardToPayloadEnum() {
    let ptr = UnsafeMutablePointer<ForwardToPayloadEnum>.allocate(capacity: 1)

    do {
        let x = ForwardToPayloadEnum.nonEmpty(SimpleClass(x: 23), 43)
        testInit(ptr, to: x)
    }

    do {
        let y = ForwardToPayloadEnum.nonEmpty(SimpleClass(x: 28), 65)

        // CHECK: Before deinit
        print("Before deinit")

        // CHECK-NEXT: SimpleClass deinitialized!
        testAssign(ptr, from: y)
    }

    // CHECK-NEXT: Before deinit
    print("Before deinit")

    // CHECK-NEXT: SimpleClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testForwardToPayloadEnum()

#if os(macOS)
func testObjc() {
    let ptr = UnsafeMutablePointer<ObjcWrapper>.allocate(capacity: 1)

    do {
        let x = ObjcWrapper(x: ObjcClass(x: 2))
        testInit(ptr, to: x)

        // CHECK-macosx: value: 2
        print("value: \(ptr.pointee.x.x)")
    }

    do {
        let x = ObjcWrapper(x: ObjcClass(x: 34))
        // CHECK-macosx-NEXT: Before deinit
        print("Before deinit")

        // CHECK-macosx-NEXT: ObjcClass deinitialized!
        testAssign(ptr, from: x)

        // CHECK-macosx-NEXT: value: 34
        print("value: \(ptr.pointee.x.x)")
    }

    // CHECK-macosx-NEXT: Before deinit
    print("Before deinit")

    // CHECK-macosx-NEXT: ObjcClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testObjc()

func testWeakObjc() {
    let ptr = UnsafeMutablePointer<WeakObjcWrapper>.allocate(capacity: 1)

    do {
        let ref = ObjcClass(x: 2)

        withExtendedLifetime(ref) {
            testInit(ptr, to: WeakObjcWrapper(x: ref))

            guard let x = ptr.pointee.x else {
                fatalError("Weak reference prematurely destroyed")
            }

            // CHECK-macosx: value: 2
            print("value: \(x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-macosx-NEXT: Before deinit
            print("Before deinit")
        }
    }

    do {
        let ref = ObjcClass(x: 34)

        withExtendedLifetime(ref) {

            // CHECK-macosx-NEXT: ObjcClass deinitialized!
            testAssign(ptr, from: WeakObjcWrapper(x: ref))

            guard let x = ptr.pointee.x else {
                fatalError("Weak reference prematurely destroyed")
            }

            // CHECK-macosx-NEXT: value: 34
            print("value: \(x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-macosx-NEXT: Before deinit
            print("Before deinit")
        }
    }

    // CHECK-macosx-NEXT: ObjcClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testWeakObjc()

func testUnownedObjc() {
    let ptr = UnsafeMutablePointer<UnownedObjcWrapper>.allocate(capacity: 1)

    do {
        let ref = ObjcClass(x: 2)
        withExtendedLifetime(ref) {
            testInit(ptr, to: UnownedObjcWrapper(x: ref))

            // CHECK-macosx: value: 2
            print("value: \(ptr.pointee.x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-macosx-NEXT: Before deinit
            print("Before deinit")
        }
    }

    do {
        let ref = ObjcClass(x: 34)
        
        withExtendedLifetime(ref) {
            // CHECK-macosx-NEXT: ObjcClass deinitialized!
            testAssign(ptr, from: UnownedObjcWrapper(x: ref))

            // CHECK-macosx-NEXT: value: 34
            print("value: \(ptr.pointee.x.x)")

            // NOTE: There is still a strong reference to it here
            // CHECK-macosx-NEXT: Before deinit
            print("Before deinit")
        }
    }

    // CHECK-macosx-NEXT: ObjcClass deinitialized!
    testDestroy(ptr)

    ptr.deallocate()
}

testUnownedObjc()
#endif
