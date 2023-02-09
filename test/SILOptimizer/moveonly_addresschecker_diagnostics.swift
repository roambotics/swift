// RUN: %target-swift-emit-sil -verify -enable-experimental-move-only -enable-experimental-feature MoveOnlyClasses %s

//////////////////
// Declarations //
//////////////////

public class CopyableKlass {}

public func borrowVal(_ x: __shared CopyableKlass) {}
public func borrowVal(_ x: __shared Klass) {}
public func borrowVal(_ s: __shared NonTrivialStruct) {}
public func borrowVal(_ s: __shared NonTrivialStruct2) {}
public func borrowVal(_ s: __shared NonTrivialCopyableStruct) {}
public func borrowVal(_ s: __shared NonTrivialCopyableStruct2) {}
public func borrowVal(_ e : __shared NonTrivialEnum) {}
public func borrowVal(_ x: __shared FinalKlass) {}
public func borrowVal(_ x: __shared AggStruct) {}
public func borrowVal(_ x: __shared AggGenericStruct<CopyableKlass>) {}
public func borrowVal<T>(_ x: __shared AggGenericStruct<T>) {}
public func borrowVal(_ x: __shared EnumTy) {}

public func consumeVal(_ x: __owned CopyableKlass) {}
public func consumeVal(_ x: __owned Klass) {}
public func consumeVal(_ x: __owned FinalKlass) {}
public func consumeVal(_ x: __owned AggStruct) {}
public func consumeVal(_ x: __owned AggGenericStruct<CopyableKlass>) {}
public func consumeVal<T>(_ x: __owned AggGenericStruct<T>) {}
public func consumeVal(_ x: __owned EnumTy) {}

@_moveOnly
public final class Klass {
    var intField: Int
    var k: Klass
    init() {
        k = Klass()
        intField = 5
    }
}

var boolValue: Bool { return true }

@_moveOnly
public struct NonTrivialStruct {
    var k = Klass()
    var copyableK = CopyableKlass()
    var nonTrivialStruct2 = NonTrivialStruct2()
    var nonTrivialCopyableStruct = NonTrivialCopyableStruct()
}

@_moveOnly
public struct NonTrivialStruct2 {
    var copyableKlass = CopyableKlass()
}

public struct NonTrivialCopyableStruct {
    var copyableKlass = CopyableKlass()
    var nonTrivialCopyableStruct2 = NonTrivialCopyableStruct2()
}

public struct NonTrivialCopyableStruct2 {
    var copyableKlass = CopyableKlass()
}

@_moveOnly
public enum NonTrivialEnum {
    case first
    case second(Klass)
    case third(NonTrivialStruct)
    case fourth(CopyableKlass)
}

@_moveOnly
public final class FinalKlass {
    var k: Klass = Klass()
}

///////////
// Tests //
///////////

/////////////////
// Class Tests //
/////////////////

public func classSimpleChainTest(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
               // expected-error @-1 {{'x2' consumed more than once}}
    x2 = x // expected-note {{consuming use here}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    let k3 = x2 // expected-note {{consuming use here}}
    let _ = k3
    borrowVal(k2)
}

public func classSimpleChainArgTest(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    var y2 = x2 // expected-note {{consuming use here}}
    y2 = x2 // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func classSimpleNonConsumingUseTest(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
    x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
}

public func classSimpleNonConsumingUseArgTest(_ x2: inout Klass) {
    borrowVal(x2)
}

public func classMultipleNonConsumingUseTest(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
    x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func classMultipleNonConsumingUseArgTest(_ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func classMultipleNonConsumingUseArgTest2(_ x2: inout Klass) { // expected-error {{'x2' used after consume}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
}

public func classMultipleNonConsumingUseArgTest3(_ x2: inout Klass) {  // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                                       // expected-error @-1 {{'x2' consumed more than once}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
                   // expected-note @-1 {{consuming use here}}
}

public func classMultipleNonConsumingUseArgTest4(_ x2: inout Klass) { // expected-error {{'x2' used after consume}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x2 = Klass()
}


public func classUseAfterConsume(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func classUseAfterConsumeArg(_ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                         // expected-error @-1 {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
                   // expected-note @-1 {{consuming use here}}
}

public func classDoubleConsume(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x  // expected-error {{'x2' consumed more than once}}
                // expected-note @-1 {{consuming use here}}
    x2 = Klass()
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func classDoubleConsumeArg(_ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                       // expected-error @-1 {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
                     // expected-note @-1 {{consuming use here}}
}

public func classLoopConsume(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-note @-1 {{consuming use here}}
    x2 = Klass()
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func classLoopConsumeArg(_ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func classLoopConsumeArg2(_ x2: inout Klass) { // expected-error {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    x2 = Klass()
}

public func classDiamond(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
    x2 = Klass()
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func classDiamondArg(_ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                 // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func classDiamondInLoop(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-error @-1 {{'x2' consumed more than once}}
               // expected-note @-2 {{consuming use here}}
    x2 = Klass()
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
                           // expected-note @-1 {{consuming use here}}
      }
    }
}

public func classDiamondInLoopArg(_ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                       // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func classDiamondInLoopArg2(_ x2: inout Klass) { // expected-error {{'x2' consumed by a use in a loop}}
                                                       // expected-error @-1 {{'x2' consumed more than once}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
                           // expected-note @-1 {{consuming use here}}
      }
    }
    x2 = Klass()
}

public func classAssignToVar1(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    x2 = Klass()
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar1Arg(_ x2: inout Klass) { // expected-error {{'x2' consumed more than once}}
                                                      // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
            // expected-note @-1 {{consuming use here}}
    x3 = Klass()
    consumeVal(x3)
}

public func classAssignToVar2(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    x2 = Klass()
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x3)
}

public func classAssignToVar2Arg(_ x2: inout Klass) { // expected-error {{'x2' consumed more than once}}
                                                      // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
            // expected-note @-1 {{consuming use here}}
    borrowVal(x3)
}

public func classAssignToVar3(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
    x2 = Klass()
    var x3 = x2
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar3Arg(_ x: Klass, _ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                            // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar3Arg2(_ x: Klass, _ x2: inout Klass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                                   // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar4(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    x2 = Klass()
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar4Arg(_ x2: inout Klass) { // expected-error {{'x2' consumed more than once}}
                                                      // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2)   // expected-note {{consuming use here}}
                // expected-note @-1 {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar5() {
    var x2 = Klass() // expected-error {{'x2' used after consume}}
    x2 = Klass()
    var x3 = x2 // expected-note {{consuming use here}}
    // TODO: Need to mark this as the lifetime extending use. We fail
    // appropriately though.
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = Klass()
    consumeVal(x3)
}

public func classAssignToVar5Arg(_ x: Klass, _ x2: inout Klass) {
    // expected-error @-1 {{'x2' used after consume}}
    // expected-error @-2 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func classAssignToVar5Arg2(_ x: Klass, _ x2: inout Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
                                                                   // expected-error @-1 {{'x2' used after consume}}
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
    x2 = Klass()
}

public func classAccessAccessField(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    x2 = Klass()
    borrowVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        borrowVal(x2.k) // expected-note {{consuming use here}}
    }
}

public func classAccessAccessFieldArg(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    borrowVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        borrowVal(x2.k) // expected-note {{consuming use here}}
    }
}

public func classAccessConsumeField(_ x: Klass) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    x2 = Klass()
    // Since a class is a reference type, we do not emit an error here.
    consumeVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.k) // expected-note {{consuming use here}}
    }
}

public func classAccessConsumeFieldArg(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // Since a class is a reference type, we do not emit an error here.
    consumeVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.k) // expected-note {{consuming use here}}
    }
}

extension Klass {
    func testNoUseSelf() { // expected-error {{'self' has guaranteed ownership but was consumed}}
        let x = self // expected-note {{consuming use here}}
        let _ = x
    }
}

/////////////////
// Final Class //
/////////////////

public func finalClassSimpleChainTest() {
    var x2 = FinalKlass()
    x2 = FinalKlass()
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func finalClassSimpleChainTestArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func finalClassSimpleChainTestArg2(_ x2: inout FinalKlass) {
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
    x2 = FinalKlass()
}

public func finalClassSimpleChainTestArg3(_ x2: inout FinalKlass) {
    for _ in 0..<1024 {}
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
    x2 = FinalKlass()
}

public func finalClassSimpleNonConsumingUseTest(_ x: __owned FinalKlass) {
    var x2 = x
    x2 = FinalKlass()
    borrowVal(x2)
}

public func finalClassSimpleNonConsumingUseTestArg(_ x2: inout FinalKlass) {
    borrowVal(x2)
}

public func finalClassMultipleNonConsumingUseTest() {
    var x2 = FinalKlass()
    x2 = FinalKlass()
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func finalClassMultipleNonConsumingUseTestArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func finalClassUseAfterConsume() {
    var x2 = FinalKlass() // expected-error {{'x2' consumed more than once}}
    x2 = FinalKlass()
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func finalClassUseAfterConsumeArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed more than once}}
                                                                   // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
              // expected-note @-1 {{consuming use here}}
}

public func finalClassDoubleConsume() {
    var x2 = FinalKlass()  // expected-error {{'x2' consumed more than once}}
    x2 = FinalKlass()
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func finalClassDoubleConsumeArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed more than once}}
                                                                 // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}    
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
                          // expected-note @-1 {{consuming use here}}
}

public func finalClassLoopConsume() {
    var x2 = FinalKlass() // expected-error {{'x2' consumed by a use in a loop}}
    x2 = FinalKlass()
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func finalClassLoopConsumeArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func finalClassDiamond() {
    var x2 = FinalKlass()
    x2 = FinalKlass()
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func finalClassDiamondArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                           // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func finalClassDiamondInLoop() {
    var x2 = FinalKlass() // expected-error {{'x2' consumed by a use in a loop}}
                          // expected-error @-1 {{'x2' consumed more than once}}
    x2 = FinalKlass()
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
                                // expected-note @-1 {{consuming use here}}
      }
    }
}

public func finalClassDiamondInLoopArg(_ x2: inout FinalKlass) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                                 // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func finalClassDiamondInLoopArg2(_ x2: inout FinalKlass) { // expected-error {{consumed by a use in a loop}}
                                                                  // expected-error @-1 {{'x2' consumed more than once}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
                                // expected-note @-1 {{consuming use here}}
      }
    }

    x2 = FinalKlass()
}

public func finalClassAssignToVar1() {
    var x2 = FinalKlass() // expected-error {{'x2' consumed more than once}}
    x2 = FinalKlass()
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    x3 = FinalKlass()
    consumeVal(x3)
}

public func finalClassAssignToVar1Arg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
    x3 = FinalKlass()
    consumeVal(x3)
}

public func finalClassAssignToVar2() {
    var x2 = FinalKlass() // expected-error {{'x2' consumed more than once}}
    x2 = FinalKlass()
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x3)
}

public func finalClassAssignToVar2Arg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
            // expected-note @-1 {{consuming use here}}
    borrowVal(x3)
}

public func finalClassAssignToVar3() {
    var x2 = Klass()
    x2 = Klass()
    var x3 = x2
    x3 = Klass()
    consumeVal(x3)
}

public func finalClassAssignToVar3Arg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = FinalKlass()
    consumeVal(x3)
}

public func finalClassAssignToVar4() {
    var x2 = FinalKlass() // expected-error {{'x2' consumed more than once}}
    x2 = FinalKlass()
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func finalClassAssignToVar4Arg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
              // expected-note @-1 {{consuming use here}}
    consumeVal(x3)
}

public func finalClassAssignToVar5() {
    var x2 = FinalKlass() // expected-error {{'x2' used after consume}}
    x2 = FinalKlass()
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = FinalKlass()
    consumeVal(x3)
}

public func finalClassAssignToVar5Arg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' used after consume}}
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = FinalKlass()
    consumeVal(x3)
}

public func finalClassAssignToVar5Arg2(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = FinalKlass()
    consumeVal(x3)
}

public func finalClassAccessField() {
    var x2 = FinalKlass()
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    x2 = FinalKlass()
    borrowVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        borrowVal(x2.k) // expected-note {{consuming use here}}
    }
}

public func finalClassAccessFieldArg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    borrowVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        borrowVal(x2.k) // expected-note {{consuming use here}}
    }
}

public func finalClassConsumeField() {
    var x2 = FinalKlass()
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    x2 = FinalKlass()

    consumeVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.k) // expected-note {{consuming use here}}
    }
}

public func finalClassConsumeFieldArg(_ x2: inout FinalKlass) {
    // expected-error @-1 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    // expected-error @-2 {{'x2' has consuming use that cannot be eliminated due to a tight exclusivity scope}}
    consumeVal(x2.k) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.k) // expected-note {{consuming use here}}
    }
}

//////////////////////
// Aggregate Struct //
//////////////////////

@_moveOnly
public struct KlassPair {
    var lhs: Klass = Klass()
    var rhs: Klass = Klass()
}

@_moveOnly
public struct AggStruct {
    var lhs: Klass = Klass()
    var center: Int = 5
    var rhs: Klass = Klass()
    var pair: KlassPair = KlassPair()

    init() {}

    // Testing that DI ignores normal init. We also get an error on our return
    // value from the function since we do not reinitialize self.
    //
    // TODO: Improve error message!
    init(myInit: Int) { // expected-error {{'self' consumed more than once}}
        let x = self // expected-note {{consuming use here}}
        let _ = x
    } // expected-note {{consuming use here}}

    // Make sure we can reinitialize successfully.
    init(myInit2: Int) {
        let x = self
        let _ = x
        self = AggStruct(myInit: myInit2)
    }

    // Testing delegating init.
    //
    // TODO: Improve error to say need to reinitialize self.lhs before end of
    // function.
    init(myInit3: Int) { // expected-error {{'self' consumed more than once}}
        self.init()
        self.center = myInit3
        let x = self.lhs // expected-note {{consuming use here}}
        let _ = x
    } // expected-note {{consuming use here}}

    init(myInit4: Int) {
        self.init()
        self.center = myInit4
        let x = self.lhs
        let _ = x
        self = AggStruct(myInit: myInit4)
    }

    init(myInit5: Int) {
        self.init()
        self.center = myInit5
        let x = self.lhs
        let _ = x
        self.lhs = Klass()
    }
}

public func aggStructSimpleChainTest() {
    var x2 = AggStruct()
    x2 = AggStruct()
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggStructSimpleChainTestArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    var y2 = x2 // expected-note {{consuming use here}}
    y2 = x2 // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func aggStructSimpleNonConsumingUseTest() {
    var x2 = AggStruct()
    x2 = AggStruct()
    borrowVal(x2)
}

public func aggStructSimpleNonConsumingUseTestArg(_ x2: inout AggStruct) {
    borrowVal(x2)
}

public func aggStructMultipleNonConsumingUseTest() {
    var x2 = AggStruct()
    x2 = AggStruct()
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggStructMultipleNonConsumingUseTestArg(_ x2: inout AggStruct) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructUseAfterConsume() {
    var x2 = AggStruct() // expected-error {{'x2' consumed more than once}}
    x2 = AggStruct()
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructUseAfterConsumeArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
              // expected-note @-1 {{consuming use here}}
}

public func aggStructDoubleConsume() {
    var x2 = AggStruct()  // expected-error {{'x2' consumed more than once}}
    x2 = AggStruct()
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructDoubleConsumeArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
}

public func aggStructLoopConsume() {
    var x2 = AggStruct() // expected-error {{'x2' consumed by a use in a loop}}
    x2 = AggStruct()
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggStructLoopConsumeArg(_ x2: inout AggStruct) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggStructDiamond() {
    var x2 = AggStruct()
    x2 = AggStruct()
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggStructDiamondArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggStructDiamondInLoop() {
    var x2 = AggStruct()
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    // expected-error @-2 {{'x2' consumed more than once}}
    x2 = AggStruct()
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming use here}}
      }
    }
}

public func aggStructDiamondInLoopArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func aggStructAccessField() {
    var x2 = AggStruct()
    x2 = AggStruct()
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggStructAccessFieldArg(_ x2: inout AggStruct) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggStructConsumeField() {
    var x2 = AggStruct() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggStruct()
    consumeVal(x2.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.lhs) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
}

public func aggStructConsumeFieldArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    consumeVal(x2.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.lhs) // expected-note {{consuming use here}}
    }
}

public func aggStructAccessGrandField() {
    var x2 = AggStruct()
    x2 = AggStruct()
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggStructAccessGrandFieldArg(_ x2: inout AggStruct) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggStructConsumeGrandField() {
    var x2 = AggStruct() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggStruct()
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
}

public func aggStructConsumeGrandFieldArg(_ x2: inout AggStruct) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    }
}

//////////////////////////////
// Aggregate Generic Struct //
//////////////////////////////

@_moveOnly
public struct AggGenericStruct<T> {
    var lhs: Klass = Klass()
    var rhs: UnsafeRawPointer? = nil
    var pair: KlassPair = KlassPair()

    // FIXME: this is the only use of the generic parameter and it's totally unused!
    // What are we testing here that's not covered by the non-generic one?
    var ptr2: UnsafePointer<T>? = nil

    init() {}

    // Testing that DI ignores normal init. We also get an error on our return
    // value from the function since we do not reinitialize self.
    //
    // TODO: Improve error message!
    init(myInit: UnsafeRawPointer) { // expected-error {{'self' consumed more than once}}
        let x = self // expected-note {{consuming use here}}
        let _ = x
    } // expected-note {{consuming use here}}

    // Make sure we can reinitialize successfully.
    init(myInit2: UnsafeRawPointer) {
        let x = self
        let _ = x
        self = AggGenericStruct(myInit: myInit2)
    }

    // Testing delegating init.
    //
    // TODO: Improve error to say need to reinitialize self.lhs before end of
    // function.
    init(myInit3: UnsafeRawPointer) { // expected-error {{'self' consumed more than once}}
        self.init()
        self.rhs = myInit3
        let x = self.lhs // expected-note {{consuming use here}}
        let _ = x
    } // expected-note {{consuming use here}}

    init(myInit4: UnsafeRawPointer) {
        self.init()
        self.rhs = myInit4
        let x = self.lhs
        let _ = x
        self = AggGenericStruct(myInit: myInit4)
    }

    init(myInit5: UnsafeRawPointer) {
        self.init()
        self.rhs = myInit5
        let x = self.lhs
        let _ = x
        self.lhs = Klass()
    }
}

public func aggGenericStructSimpleChainTest() {
    var x2 = AggGenericStruct<CopyableKlass>()
    x2 = AggGenericStruct<CopyableKlass>()
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleChainTestArg(_ x2: inout AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleNonConsumingUseTest() {
    var x2 = AggGenericStruct<CopyableKlass>()
    x2 = AggGenericStruct<CopyableKlass>()
    borrowVal(x2)
}

public func aggGenericStructSimpleNonConsumingUseTestArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    borrowVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTest() {
    var x2 = AggGenericStruct<CopyableKlass>()
    x2 = AggGenericStruct<CopyableKlass>()
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTestArg(_ x2: inout AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsume() {
    var x2 = AggGenericStruct<CopyableKlass>() // expected-error {{'x2' consumed more than once}}
    x2 = AggGenericStruct<CopyableKlass>()
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsumeArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}x
}

public func aggGenericStructDoubleConsume() {
    var x2 = AggGenericStruct<CopyableKlass>()  // expected-error {{'x2' consumed more than once}}
    x2 = AggGenericStruct<CopyableKlass>()
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsumeArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
}

public func aggGenericStructLoopConsume() {
    var x2 = AggGenericStruct<CopyableKlass>() // expected-error {{'x2' consumed by a use in a loop}}
    x2 = AggGenericStruct<CopyableKlass>()
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructLoopConsumeArg(_ x2: inout AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructDiamond() {
    var x2 = AggGenericStruct<CopyableKlass>()
    x2 = AggGenericStruct<CopyableKlass>()
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggGenericStructDiamondArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructDiamondInLoop() {
    var x2 = AggGenericStruct<CopyableKlass>() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggGenericStruct<CopyableKlass>()
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming use here}}
      }
    }
}

public func aggGenericStructDiamondInLoopArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func aggGenericStructAccessField() {
    var x2 = AggGenericStruct<CopyableKlass>()
    x2 = AggGenericStruct<CopyableKlass>()
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructAccessFieldArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructConsumeField() {
    var x2 = AggGenericStruct<CopyableKlass>() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggGenericStruct<CopyableKlass>()
    consumeVal(x2.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.lhs) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
}

public func aggGenericStructConsumeFieldArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    consumeVal(x2.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.lhs) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructAccessGrandField() {
    var x2 = AggGenericStruct<CopyableKlass>()
    x2 = AggGenericStruct<CopyableKlass>()
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructAccessGrandFieldArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandField() {
    var x2 = AggGenericStruct<CopyableKlass>() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggGenericStruct<CopyableKlass>()
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
}

public func aggGenericStructConsumeGrandField2() {
    var x2 = AggGenericStruct<CopyableKlass>() // expected-error {{'x2' consumed more than once}}
    x2 = AggGenericStruct<CopyableKlass>()
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
    }
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
}

public func aggGenericStructConsumeGrandFieldArg(_ x2: inout AggGenericStruct<CopyableKlass>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    }
}

////////////////////////////////////////////////////////////
// Aggregate Generic Struct + Generic But Body is Trivial //
////////////////////////////////////////////////////////////

public func aggGenericStructSimpleChainTest<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>()
    x2 = AggGenericStruct<T>()
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleChainTestArg<T>(_ x2: inout AggGenericStruct<T>) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleNonConsumingUseTest<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>()
    x2 = AggGenericStruct<T>()
    borrowVal(x2)
}

public func aggGenericStructSimpleNonConsumingUseTestArg<T>(_ x2: inout AggGenericStruct<T>) {
    borrowVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTest<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>()
    x2 = AggGenericStruct<T>()
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTestArg<T>(_ x2: inout AggGenericStruct<T>) { //expected-error {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsume<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>() // expected-error {{'x2' consumed more than once}}
    x2 = AggGenericStruct<T>()
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsumeArg<T>(_ x2: inout AggGenericStruct<T>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
}

public func aggGenericStructDoubleConsume<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>() // expected-error {{'x2' consumed more than once}}
    x2 = AggGenericStruct<T>()
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsumeArg<T>(_ x2: inout AggGenericStruct<T>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
}

public func aggGenericStructLoopConsume<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>() // expected-error {{'x2' consumed by a use in a loop}}
    x2 = AggGenericStruct<T>()
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructLoopConsumeArg<T>(_ x2: inout AggGenericStruct<T>) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructDiamond<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>()
    x2 = AggGenericStruct<T>()
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggGenericStructDiamondArg<T>(_ x2: inout AggGenericStruct<T>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructDiamondInLoop<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>() // expected-error {{'x2' consumed more than once}}
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    x2 = AggGenericStruct<T>()
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming use here}}
      }
    }
}

public func aggGenericStructDiamondInLoopArg<T>(_ x2: inout AggGenericStruct<T>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func aggGenericStructAccessField<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>()
    x2 = AggGenericStruct<T>()
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructAccessFieldArg<T>(_ x2: inout AggGenericStruct<T>) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructConsumeField<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggGenericStruct<T>()
    consumeVal(x2.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.lhs) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
}

public func aggGenericStructConsumeFieldArg<T>(_ x2: inout AggGenericStruct<T>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    consumeVal(x2.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.lhs) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructAccessGrandField<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>()
    x2 = AggGenericStruct<T>()
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructAccessGrandFieldArg<T>(_ x2: inout AggGenericStruct<T>) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandField<T>(_ x: T.Type) {
    var x2 = AggGenericStruct<T>() // expected-error {{'x2' consumed by a use in a loop}}
    // expected-error @-1 {{'x2' consumed more than once}}
    x2 = AggGenericStruct<T>()
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
}

public func aggGenericStructConsumeGrandFieldArg<T>(_ x2: inout AggGenericStruct<T>) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs) // expected-note {{consuming use here}}
    }
}

/////////////////////
// Enum Test Cases //
/////////////////////

@_moveOnly
public enum EnumTy {
    case klass(Klass)
    case int(Int)

    func doSomething() -> Bool { true }
}

public func enumSimpleChainTest() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func enumSimpleChainTestArg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func enumSimpleNonConsumingUseTest() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    borrowVal(x2)
}

public func enumSimpleNonConsumingUseTestArg(_ x2: inout EnumTy) {
    borrowVal(x2)
}

public func enumMultipleNonConsumingUseTest() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func enumMultipleNonConsumingUseTestArg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumUseAfterConsume() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed more than once}}
    x2 = EnumTy.klass(Klass())
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumUseAfterConsumeArg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
}

public func enumDoubleConsume() {
    var x2 = EnumTy.klass(Klass())  // expected-error {{'x2' consumed more than once}}
    x2 = EnumTy.klass(Klass())
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumDoubleConsumeArg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}} 
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
}

public func enumLoopConsume() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed by a use in a loop}}
    x2 = EnumTy.klass(Klass())
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func enumLoopConsumeArg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func enumDiamond() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func enumDiamondArg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func enumDiamondInLoop() {
    var x2 = EnumTy.klass(Klass())
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    // expected-error @-2 {{'x2' consumed more than once}} 
    x2 = EnumTy.klass(Klass())
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming use here}}
      }
    }
}

public func enumDiamondInLoopArg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func enumAssignToVar1() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed more than once}}
    x2 = EnumTy.klass(Klass())
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}

public func enumAssignToVar1Arg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}} 
                                                            
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}

public func enumAssignToVar2() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed more than once}}
    x2 = EnumTy.klass(Klass())
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x3)
}

public func enumAssignToVar2Arg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}} 
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
     // expected-note @-1 {{consuming use here}}
    borrowVal(x3)
}

public func enumAssignToVar3() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    var x3 = x2
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}

public func enumAssignToVar3Arg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                            
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}

public func enumAssignToVar4() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed more than once}}
    x2 = EnumTy.klass(Klass())
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar4Arg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}} 
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    // expected-note @-1 {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar5() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' used after consume}}
    x2 = EnumTy.klass(Klass())
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}

public func enumAssignToVar5Arg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' used after consume}}
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}

public func enumAssignToVar5Arg2(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
                                                            
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = EnumTy.klass(Klass())
    consumeVal(x3)
}


public func enumPatternMatchIfLet1() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed more than once}}
    x2 = EnumTy.klass(Klass())
    if case let EnumTy.klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x)
    }
    if case let EnumTy.klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x)
    }
}

public func enumPatternMatchIfLet1Arg(_ x2: inout EnumTy) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed more than once}}
    if case let EnumTy.klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x)
    }
    if case let EnumTy.klass(x) = x2 { // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
        borrowVal(x)
    }
}

public func enumPatternMatchIfLet2() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' consumed by a use in a loop}}
    x2 = EnumTy.klass(Klass())
    for _ in 0..<1024 {
        if case let EnumTy.klass(x) = x2 {  // expected-note {{consuming use here}}
            borrowVal(x)
        }
    }
}

public func enumPatternMatchIfLet2Arg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    for _ in 0..<1024 {
        if case let EnumTy.klass(x) = x2 {  // expected-note {{consuming use here}}
            borrowVal(x)
        }
    }
}

// This is wrong.
public func enumPatternMatchSwitch1() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' used after consume}}
    x2 = EnumTy.klass(Klass())
    switch x2 { // expected-note {{consuming use here}}
    case let EnumTy.klass(k):
        borrowVal(k)
        // This should be flagged as the use after free use. We are atleast
        // erroring though.
        borrowVal(x2) // expected-note {{non-consuming use here}}
    case .int:
        break
    }
}

public func enumPatternMatchSwitch1Arg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    switch x2 { // expected-note {{consuming use here}}
    case let EnumTy.klass(k):
        borrowVal(k)
        // This should be flagged as the use after free use. We are atleast
        // erroring though.
        borrowVal(x2)
    case .int:
        break
    }
}

public func enumPatternMatchSwitch2() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    switch x2 {
    case let EnumTy.klass(k):
        borrowVal(k)
    case .int:
        break
    }
}

public func enumPatternMatchSwitch2Arg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    switch x2 { // expected-note {{consuming use here}}
    case let EnumTy.klass(k):
        borrowVal(k)
    case .int:
        break
    }
}

// QOI: We can do better here. We should also flag x2
public func enumPatternMatchSwitch2WhereClause() {
    var x2 = EnumTy.klass(Klass()) // expected-error {{'x2' used after consume}}
    x2 = EnumTy.klass(Klass())
    switch x2 { // expected-note {{consuming use here}}
    case let EnumTy.klass(k)
           where x2.doSomething(): // expected-note {{non-consuming use here}}
        borrowVal(k)
    case .int:
        break
    case EnumTy.klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClauseArg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    switch x2 { // expected-note {{consuming use here}}
    case let EnumTy.klass(k)
           where x2.doSomething():
        borrowVal(k)
    case .int:
        break
    case EnumTy.klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClause2() {
    var x2 = EnumTy.klass(Klass())
    x2 = EnumTy.klass(Klass())
    switch x2 {
    case let EnumTy.klass(k)
           where boolValue:
        borrowVal(k)
    case .int:
        break
    case EnumTy.klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClause2Arg(_ x2: inout EnumTy) { // expected-error {{'x2' consumed but not reinitialized before end of function}}
    switch x2 { // expected-note {{consuming use here}}
    case let EnumTy.klass(k)
           where boolValue:
        borrowVal(k)
    case .int:
        break
    case EnumTy.klass:
        break
    }
}

/////////////////////////////
// Closure and Defer Tests //
/////////////////////////////

public func closureClassUseAfterConsume1() {
    let f = {
        var x2 = Klass() // expected-error {{'x2' consumed more than once}}
        x2 = Klass()
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
}

public func closureClassUseAfterConsume2() {
    let f = { () in
        var x2 = Klass() // expected-error {{'x2' consumed more than once}}
        x2 = Klass()
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
}

public func closureClassUseAfterConsumeArg(_ argX: inout Klass) {
    // TODO: Fix this
    let f = { (_ x2: inout Klass) in
        // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
        // expected-error @-2 {{'x2' consumed more than once}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
    f(&argX)
}

// We do not support captures of vars by closures today.
//
// TODO: Why are we erroring for the same variable twice?
public func closureCaptureClassUseAfterConsume() {
    var x2 = Klass()
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed more than once}}
    // expected-error @-3 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-4 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-5 {{'x2' consumed in closure but not reinitialized before end of closure}}
    x2 = Klass()
    let f = {
        borrowVal(x2)
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        // expected-note @-3 {{consuming use here}}
        // expected-note @-4 {{consuming use here}}
    }
    f()
}

public func closureCaptureClassUseAfterConsume2() {
    var x2 = Klass()
    // expected-error @-1 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-2 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-3 {{'x2' consumed in closure but not reinitialized before end of closure}}
    x2 = Klass()
    let f = {
        borrowVal(x2)
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
    }
    f()
}

public func closureCaptureClassUseAfterConsumeError() {
    var x2 = Klass()
    // expected-error @-1 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-2 {{'x2' consumed more than once}}
    // expected-error @-3 {{'x2' consumed more than once}}
    // expected-error @-4 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-5 {{'x2' consumed in closure but not reinitialized before end of closure}}
    x2 = Klass()
    let f = {
        borrowVal(x2)
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        // expected-note @-3 {{consuming use here}}
        // expected-note @-4 {{consuming use here}}
    }
    f()
    let x3 = x2
    let _ = x3
}

public func closureCaptureClassArgUseAfterConsume(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-3 {{'x2' consumed more than once}}
    // expected-note @-4 {{'x2' is declared 'inout'}}
    let f = { // expected-note {{consuming use here}}
        // expected-error @-1 {{escaping closure captures 'inout' parameter 'x2'}}
        borrowVal(x2) // expected-note {{captured here}}
        consumeVal(x2) // expected-note {{captured here}}
        // expected-note @-1 {{consuming use here}}
        consumeVal(x2) // expected-note {{captured here}}
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
    }
    f()
}

public func deferCaptureClassUseAfterConsume() {
    var x2 = Klass()
    // expected-error @-1 {{'x2' used after consume}}
    // expected-error @-2 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-3 {{'x2' consumed more than once}}
    x2 = Klass()
    defer { // expected-note {{non-consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
    }
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func deferCaptureClassUseAfterConsume2() {
    var x2 = Klass()
    // expected-error @-1 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-2 {{'x2' consumed more than once}}
    // expected-error @-3 {{'x2' used after consume}}
    x2 = Klass()
    defer { // expected-note {{non-consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
    let x3 = x2 // expected-note {{consuming use here}}
    let _ = x3
}

public func deferCaptureClassArgUseAfterConsume(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-2 {{'x2' consumed more than once}}
    borrowVal(x2)
    defer {
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
    }
    print("foo")
}

public func closureAndDeferCaptureClassUseAfterConsume() {
    var x2 = Klass()
    // expected-error @-1 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-2 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-3 {{'x2' consumed more than once}}
    x2 = Klass()
    let f = {
        defer {
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
        }
        print("foo")
    }
    f()
}

public func closureAndDeferCaptureClassUseAfterConsume2() {
    var x2 = Klass()
    // expected-error @-1 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-2 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-3 {{'x2' consumed more than once}}
    // expected-error @-4 {{'x2' used after consume}}
    // expected-error @-5 {{'x2' used after consume}}
    x2 = Klass()
    let f = {
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        defer {
            // expected-note @-1 {{non-consuming use here}}
            // expected-note @-2 {{non-consuming use here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
        }
        print("foo")
    }
    f()
}

public func closureAndDeferCaptureClassUseAfterConsume3() {
    var x2 = Klass()
    // expected-error @-1 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-2 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-3 {{'x2' consumed more than once}}
    // expected-error @-4 {{'x2' used after consume}}
    // expected-error @-5 {{'x2' used after consume}}
    x2 = Klass()
    let f = {
        consumeVal(x2)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        defer {
            // expected-note @-1 {{non-consuming use here}}
            // expected-note @-2 {{non-consuming use here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
        }
        print("foo")
    }
    f()
    consumeVal(x2)
}

public func closureAndDeferCaptureClassArgUseAfterConsume(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-3 {{'x2' consumed more than once}}
    // expected-note @-4 {{'x2' is declared 'inout'}}
    let f = { // expected-error {{escaping closure captures 'inout' parameter 'x2'}}
              // expected-note @-1 {{consuming use here}}
        defer { // expected-note {{captured indirectly by this call}}
            borrowVal(x2) // expected-note {{captured here}}
            consumeVal(x2) // expected-note {{captured here}}
            // expected-note @-1 {{consuming use here}}
            consumeVal(x2) // expected-note {{captured here}}
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
        }
        print("foo")
    }
    f()
}

public func closureAndClosureCaptureClassUseAfterConsume() {
    var x2 = Klass()
    // expected-error @-1 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-2 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-3 {{'x2' consumed more than once}}
    // expected-error @-4 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-5 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-6 {{'x2' consumed more than once}}
    // expected-error @-7 {{'x2' consumed in closure but not reinitialized before end of closure}}
    x2 = Klass()
    let f = {
        let g = {
            borrowVal(x2)
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
            // expected-note @-3 {{consuming use here}}
            // expected-note @-4 {{consuming use here}}
        }
        g()
    }
    f()
}

public func closureAndClosureCaptureClassUseAfterConsume2() {
    var x2 = Klass()
    // expected-error @-1 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-2 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-3 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-4 {{'x2' consumed more than once}}
    // expected-error @-5 {{'x2' consumed more than once}}
    // expected-error @-6 {{Usage of a move only type that the move checker does not know how to check!}}
    // expected-error @-7 {{'x2' consumed in closure but not reinitialized before end of closure}}
    x2 = Klass()
    let f = {
        let g = {
            borrowVal(x2)
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
            consumeVal(x2)
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{consuming use here}}
            // expected-note @-3 {{consuming use here}}
            // expected-note @-4 {{consuming use here}}
        }
        g()
    }
    f()
    consumeVal(x2)
}


public func closureAndClosureCaptureClassArgUseAfterConsume(_ x2: inout Klass) {
    // expected-error @-1 {{'x2' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-3 {{'x2' consumed in closure but not reinitialized before end of closure}}
    // expected-error @-4 {{'x2' consumed more than once}}
    // expected-note @-5 {{'x2' is declared 'inout'}}
    // expected-note @-6 {{'x2' is declared 'inout'}}
    let f = { // expected-error {{escaping closure captures 'inout' parameter 'x2'}}
              // expected-note @-1 {{consuming use here}}
        let g = { // expected-error {{escaping closure captures 'inout' parameter 'x2'}}
            // expected-note @-1 {{consuming use here}}
            // expected-note @-2 {{captured indirectly by this call}}
            borrowVal(x2)
            // expected-note @-1 {{captured here}}
            // expected-note @-2 {{captured here}}
            consumeVal(x2)
            // expected-note @-1 {{captured here}}
            // expected-note @-2 {{captured here}}
            // expected-note @-3 {{consuming use here}}
            consumeVal(x2)
            // expected-note @-1 {{captured here}}
            // expected-note @-2 {{captured here}}
            // expected-note @-3 {{consuming use here}}
            // expected-note @-4 {{consuming use here}}
        }
        g()
    }
    f()
}

/////////////////////////////
// Tests For Move Operator //
/////////////////////////////

func moveOperatorTest(_ k: __owned Klass) {
    var k2 = k
    // expected-error @-1 {{'k2' consumed more than once}}
    // expected-error @-2 {{'k2' consumed more than once}}
    // expected-error @-3 {{'k2' consumed more than once}}
    k2 = Klass()
    let k3 = _move k2 // expected-note {{consuming use here}}
    let _ = _move k2
    // expected-note @-1 {{consuming use here}}
    // expected-note @-2 {{consuming use here}}
    _ = k2
    // expected-note @-1 {{consuming use here}}
    // expected-note @-2 {{consuming use here}}
    let _ = k2
    // expected-note @-1 {{consuming use here}}
    let _ = k3
}

/////////////////////////////////////////
// Black hole initialization test case//
/////////////////////////////////////////

func blackHoleKlassTestCase(_ k: __owned Klass) {
    var k2 = k
    // expected-error @-1 {{'k2' consumed more than once}}
    // expected-error @-2 {{'k2' consumed more than once}}
    // expected-error @-3 {{'k2' consumed more than once}}
    // expected-error @-4 {{'k2' consumed more than once}}
    let _ = k2 // expected-note {{consuming use here}}
    let _ = k2 // expected-note {{consuming use here}}

    k2 = Klass()
    var _ = k2 // expected-note {{consuming use here}}
    var _ = k2
    // expected-note @-1 {{consuming use here}}
    // expected-note @-2 {{consuming use here}}

    _ = k2
    // expected-note @-1 {{consuming use here}}
    // expected-note @-2 {{consuming use here}}

    // TODO: Why do we not also get 2 errors here?
    _ = k2
    // expected-note @-1 {{consuming use here}}
}

///////////////////////////////////////
// Copyable Type in a Move Only Type //
///////////////////////////////////////

func copyableKlassInAMoveOnlyStruct() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    borrowVal(a.copyableK)
    consumeVal(a.copyableK)
}

// This shouldn't error since we are consuming a copyable type.
func copyableKlassInAMoveOnlyStruct2() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    borrowVal(a.copyableK)
    consumeVal(a.copyableK)
    consumeVal(a.copyableK)
}

// This shouldn't error since we are working with a copyable type.
func copyableKlassInAMoveOnlyStruct3() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    borrowVal(a.copyableK)
    consumeVal(a.copyableK)
    borrowVal(a.copyableK)
}

// This used to error, but no longer errors since we are using a true field
// sensitive model.
func copyableKlassInAMoveOnlyStruct4() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    borrowVal(a.copyableK)
    consumeVal(a.copyableK)
    borrowVal(a.nonTrivialStruct2)
}

func copyableStructsInMoveOnlyStructNonConsuming() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    borrowVal(a)
    borrowVal(a.nonTrivialStruct2)
    borrowVal(a.nonTrivialCopyableStruct)
    borrowVal(a.nonTrivialCopyableStruct.nonTrivialCopyableStruct2)
    borrowVal(a.nonTrivialCopyableStruct.nonTrivialCopyableStruct2.copyableKlass)
}

///////////////////////////
// Field Sensitive Tests //
///////////////////////////

func fieldSensitiveTestReinitField() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    consumeVal(a.k)
    a.k = Klass()
    borrowVal(a.k)
}

func fieldSensitiveTestReinitFieldMultiBlock1() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    consumeVal(a.k)

    if boolValue {
        a.k = Klass()
        borrowVal(a.k)
    }
}

func fieldSensitiveTestReinitFieldMultiBlock2() {
    var a = NonTrivialStruct() // expected-error {{'a' used after consume}}
    a = NonTrivialStruct()
    consumeVal(a.k) // expected-note {{consuming use here}}

    if boolValue {
        a.k = Klass()
    }

    borrowVal(a.k) // expected-note {{non-consuming use here}}
}

func fieldSensitiveTestReinitFieldMultiBlock3() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    consumeVal(a.k)

    if boolValue {
        a.k = Klass()
    } else {
        a.k = Klass()
    }

    borrowVal(a.k)
}

// This test sees what happens if we partially reinit along one path and do a
// full reinit along another path.
func fieldSensitiveTestReinitFieldMultiBlock4() {
    var a = NonTrivialStruct()
    a = NonTrivialStruct()
    consumeVal(a.k)

    if boolValue {
        a.k = Klass()
    } else {
        a = NonTrivialStruct()
    }

    borrowVal(a.k)
}

func fieldSensitiveTestReinitEnumMultiBlock() {
    var e = NonTrivialEnum.first // expected-error {{'e' used after consume}}
    e = NonTrivialEnum.second(Klass())
    switch e { // expected-note {{consuming use here}}
    case .second:
        e = NonTrivialEnum.third(NonTrivialStruct())
    default:
        break
    }
    borrowVal(e) // expected-note {{non-consuming use here}}
}

func fieldSensitiveTestReinitEnumMultiBlock1() {
    var e = NonTrivialEnum.first
    e = NonTrivialEnum.second(Klass())
    switch e {
    case .second:
        e = NonTrivialEnum.third(NonTrivialStruct())
    default:
        e = NonTrivialEnum.fourth(CopyableKlass())
    }
    borrowVal(e)
}

func fieldSensitiveTestReinitEnumMultiBlock2() {
    var e = NonTrivialEnum.first
    e = NonTrivialEnum.second(Klass())
    if boolValue {
        switch e {
        case .second:
            e = NonTrivialEnum.third(NonTrivialStruct())
        default:
            e = NonTrivialEnum.fourth(CopyableKlass())
        }
    } else {
        e = NonTrivialEnum.third(NonTrivialStruct())
    }
    borrowVal(e)
}

////////////////////////////////////////////
// Multiple Use by Same CallSite TestCase //
////////////////////////////////////////////

func sameCallSiteTestConsumeTwice(_ k: inout Klass) { // expected-error {{'k' consumed more than once}}
    func consumeKlassTwice(_ k: __owned Klass, _ k2: __owned Klass) {}
    consumeKlassTwice(k, k)
    // expected-note @-1 {{consuming use here}}
    // expected-note @-2 {{consuming use here}}
    k = Klass()
}

func sameCallSiteConsumeAndUse(_ k: inout Klass) { // expected-error {{'k' used after consume}}
    func consumeKlassAndUseKlass(_ k: __owned Klass, _ k2: Klass) {}
    consumeKlassAndUseKlass(k, k)
    // expected-note @-1 {{consuming use here}}
    // expected-note @-2 {{non-consuming use here}}
    k = Klass()
}
