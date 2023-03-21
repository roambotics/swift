// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -I %S/Inputs -enable-experimental-cxx-interop -emit-ir %s -Xcc -fignore-exceptions -O | %FileCheck %s

import CopyMoveAssignment

@inline(never)
func takeValue<T>(_ x: T) {
    let _ = x
}

@inline(never)
public func copyAssign() {
    var instance = NonTrivialCopyAndCopyMoveAssign()
    let instance2 = NonTrivialCopyAndCopyMoveAssign()
    instance = instance2
    takeValue(instance2)
    takeValue(instance)
}

// CHECK-LABEL: define {{.*}}copyAssign
// CHECK: call {{void|\%struct.NonTrivialCopyAndCopyMoveAssign\*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignC1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignC2Ev|"\?\?0NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE:.*]])
// CHECK: call {{void|\%struct.NonTrivialCopyAndCopyMoveAssign\*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignC1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignC2Ev|"\?\?0NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE2:.*]])
// CHECK: call {{void|\%struct.NonTrivialCopyAndCopyMoveAssign\*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignD1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignD2Ev|"\?\?1NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE]])
// CHECK: call {{void|\%struct.NonTrivialCopyAndCopyMoveAssign\*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignC1ERKS_|_ZN31NonTrivialCopyAndCopyMoveAssignC2ERKS_|"\?\?0NonTrivialCopyAndCopyMoveAssign@@QEAA@AEBU0@@Z"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE]], %struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE2]])
// CHECK: call {{.*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignD1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignD2Ev|"\?\?1NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE2]])
// CHECK: call {{.*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignD1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignD2Ev|"\?\?1NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[COPY_INSTANCE]])

// CHECK-LABEL: define {{.*}}takeAssign
// CHECK: call {{void|\%struct.NonTrivialCopyAndCopyMoveAssign\*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignC1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignC2Ev|"\?\?0NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[MOVE_INSTANCE:.*]])
// CHECK: call {{.*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignD1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignD2Ev|"\?\?1NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[MOVE_INSTANCE]])
// CHECK: call {{.*}} @{{_ZN31NonTrivialCopyAndCopyMoveAssignD1Ev|_ZN31NonTrivialCopyAndCopyMoveAssignD2Ev|"\?\?1NonTrivialCopyAndCopyMoveAssign@@QEAA@XZ"}}(%struct.NonTrivialCopyAndCopyMoveAssign* %[[MOVE_INSTANCE]])

// CHECK-LABEL: }

@inline(never)
public func takeAssign() {
    var instance = NonTrivialCopyAndCopyMoveAssign()
    instance = NonTrivialCopyAndCopyMoveAssign()
    takeValue(instance)
}

copyAssign()
takeAssign()
