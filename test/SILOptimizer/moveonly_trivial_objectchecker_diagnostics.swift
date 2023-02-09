// RUN: %target-swift-emit-sil -verify -enable-experimental-move-only %s

//////////////////
// Declarations //
//////////////////

public class CopyableKlass {}

var boolValue: Bool { return true }

@_moveOnly
public struct NonTrivialStruct {
    var i: Int = 0
}

public func borrowVal(_ x: __shared Int) {}
public func borrowVal(_ x: __shared AggStruct) {}
public func borrowVal(_ x: __shared NonTrivialStruct) {}
public func borrowVal(_ x: __shared AggGenericStruct<CopyableKlass>) {}
public func borrowVal<T>(_ x: __shared AggGenericStruct<T>) {}
public func borrowVal(_ x: __shared EnumTy) {}

public func consumeVal(_ x: __owned Int) {}
public func consumeVal(_ x: __owned NonTrivialStruct) {}
public func consumeVal(_ x: __owned String) {}
public func consumeVal(_ x: __owned EnumTy) {}
public func consumeVal<T>(_ x: __owned AggGenericStruct<T>) {}
public func consumeVal(_ x: __owned AggStruct) {}
public func consumeVal(_ x: __owned AggGenericStruct<CopyableKlass>) {}


@_moveOnly
public enum NonTrivialEnum {
    case first
    case second((Int, Int))
    case third(NonTrivialStruct)
}

///////////
// Tests //
///////////

//////////////////////
// Aggregate Struct //
//////////////////////

@_moveOnly
public struct MOIntPair {
    var lhs: Int
    var rhs: Int
}

@_moveOnly
public struct AggStruct {
    var lhs: Int
    var center: Int
    var rhs: Int
    var pair: MOIntPair
}

public func aggStructSimpleChainTest(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggStructSimpleChainTestArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func aggStructSimpleChainTestOwnedArg(_ x2: __owned AggStruct) {
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggStructSimpleNonConsumingUseTest(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
}

public func aggStructSimpleNonConsumingUseTestArg(_ x2: AggStruct) {
    borrowVal(x2)
}

public func aggStructSimpleNonConsumingUseTestOwnedArg(_ x2: __owned AggStruct) {
    borrowVal(x2)
}

public func aggStructMultipleNonConsumingUseTest(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggStructMultipleNonConsumingUseTestArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructMultipleNonConsumingUseTestOwnedArg(_ x2: __owned AggStruct) {
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggStructUseAfterConsume(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructUseAfterConsumeArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructUseAfterConsumeOwnedArg(_ x2: __owned AggStruct) { // expected-error {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructDoubleConsume(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x  // expected-error {{'x2' consumed more than once}}
                // expected-note @-1 {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructDoubleConsumeArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructDoubleConsumeOwnedArg(_ x2: __owned AggStruct) { // expected-error {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggStructLoopConsume(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-note @-1 {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func aggStructLoopConsumeArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggStructLoopConsumeOwnedArg(_ x2: __owned AggStruct) { // expected-error {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func aggStructDiamond(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggStructDiamondArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggStructDiamondOwnedArg(_ x2: __owned AggStruct) {
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggStructDiamondInLoop(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func aggStructDiamondInLoopArg(_ x2: AggStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func aggStructDiamondInLoopOwnedArg(_ x2: __owned AggStruct) { // expected-error {{'x2' consumed more than once}}
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func aggStructAccessField(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggStructAccessFieldArg(_ x2: AggStruct) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggStructAccessFieldOwnedArg(_ x2: __owned AggStruct) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggStructConsumeField(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

// TODO: We should error here!
public func aggStructConsumeFieldArg(_ x2: AggStruct) {
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggStructConsumeFieldOwnedArg(_ x2: __owned AggStruct) {
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggStructAccessGrandField(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggStructAccessGrandFieldArg(_ x2: AggStruct) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggStructAccessGrandFieldOwnedArg(_ x2: __owned AggStruct) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggStructConsumeGrandField(_ x: AggStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

// TODO: This needs to error.
public func aggStructConsumeGrandFieldArg(_ x2: AggStruct) {
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

public func aggStructConsumeGrandFieldOwnedArg(_ x2: __owned AggStruct) {
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

//////////////////////////////
// Aggregate Generic Struct //
//////////////////////////////

@_moveOnly
public struct AggGenericStruct<T> {
    var lhs: Int
    var rhs: UnsafeRawPointer
    var pair: MOIntPair
}

public func aggGenericStructSimpleChainTest(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleChainTestArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleChainTestOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleNonConsumingUseTest(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
}

public func aggGenericStructSimpleNonConsumingUseTestArg(_ x2: AggGenericStruct<CopyableKlass>) {
    borrowVal(x2)
}

public func aggGenericStructSimpleNonConsumingUseTestOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    borrowVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTest(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTestArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructMultipleNonConsumingUseTestOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggGenericStructUseAfterConsume(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsumeArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsumeOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsume(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x  // expected-error {{'x2' consumed more than once}}
                // expected-note @-1 {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsumeArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsumeOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructLoopConsume(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-note @-1 {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func aggGenericStructLoopConsumeArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructLoopConsumeOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func aggGenericStructDiamond(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggGenericStructDiamondArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructDiamondOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggGenericStructDiamondInLoop(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func aggGenericStructDiamondInLoopArg(_ x2: AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func aggGenericStructDiamondInLoopOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) { // expected-error {{'x2' consumed more than once}}
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{other consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func aggGenericStructAccessField(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructAccessFieldArg(_ x2: AggGenericStruct<CopyableKlass>) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructAccessFieldOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructConsumeField(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggGenericStructConsumeFieldArg(_ x2: AggGenericStruct<CopyableKlass>) {
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggGenericStructConsumeFieldOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggGenericStructAccessGrandField(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructAccessGrandFieldArg(_ x2: AggGenericStruct<CopyableKlass>) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructAccessGrandFieldOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandField(_ x: AggGenericStruct<CopyableKlass>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandFieldArg(_ x2: AggGenericStruct<CopyableKlass>) {
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandFieldOwnedArg(_ x2: __owned AggGenericStruct<CopyableKlass>) {
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

////////////////////////////////////////////////////////////
// Aggregate Generic Struct + Generic But Body is Trivial //
////////////////////////////////////////////////////////////

public func aggGenericStructSimpleChainTest<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleChainTestArg<T>(_ x2: AggGenericStruct<T>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleChainTestOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func aggGenericStructSimpleNonConsumingUseTest<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
}

public func aggGenericStructSimpleNonConsumingUseTestArg<T>(_ x2: AggGenericStruct<T>) {
    borrowVal(x2)
}

public func aggGenericStructSimpleNonConsumingUseTestOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    borrowVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTest<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggGenericStructMultipleNonConsumingUseTestArg<T>(_ x2: AggGenericStruct<T>) { //expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructMultipleNonConsumingUseTestOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func aggGenericStructUseAfterConsume<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsumeArg<T>(_ x2: AggGenericStruct<T>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructUseAfterConsumeOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) { // expected-error {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsume<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x  // expected-error {{'x2' consumed more than once}}
                // expected-note @-1 {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsumeArg<T>(_ x2: AggGenericStruct<T>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructDoubleConsumeOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) { // expected-error {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func aggGenericStructLoopConsume<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-note @-1 {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func aggGenericStructLoopConsumeArg<T>(_ x2: AggGenericStruct<T>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructLoopConsumeOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) { // expected-error {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func aggGenericStructDiamond<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggGenericStructDiamondArg<T>(_ x2: AggGenericStruct<T>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func aggGenericStructDiamondOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func aggGenericStructDiamondInLoop<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func aggGenericStructDiamondInLoopArg<T>(_ x2: AggGenericStruct<T>) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func aggGenericStructDiamondInLoopOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) { // expected-error {{'x2' consumed more than once}}
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func aggGenericStructAccessField<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructAccessFieldArg<T>(_ x2: AggGenericStruct<T>) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructAccessFieldOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    borrowVal(x2.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.lhs)
    }
}

public func aggGenericStructConsumeField<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggGenericStructConsumeFieldArg<T>(_ x2: AggGenericStruct<T>) {
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggGenericStructConsumeFieldOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    consumeVal(x2.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.lhs)
    }
}

public func aggGenericStructAccessGrandField<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructAccessGrandFieldArg<T>(_ x2: AggGenericStruct<T>) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructAccessGrandFieldOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    borrowVal(x2.pair.lhs)
    for _ in 0..<1024 {
        borrowVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandField<T>(_ x: AggGenericStruct<T>) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandFieldArg<T>(_ x2: AggGenericStruct<T>) {
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

public func aggGenericStructConsumeGrandFieldOwnedArg<T>(_ x2: __owned AggGenericStruct<T>) {
    consumeVal(x2.pair.lhs)
    for _ in 0..<1024 {
        consumeVal(x2.pair.lhs)
    }
}

/////////////////////
// Enum Test Cases //
/////////////////////

@_moveOnly
public enum EnumTy {
    case klass(NonTrivialStruct)
    case int(Int)

    func doSomething() -> Bool { true }
}

public func enumSimpleChainTest(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func enumSimpleChainTestArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    let y2 = x2 // expected-note {{consuming use here}}
    let k2 = y2
    borrowVal(k2)
}

public func enumSimpleChainTestOwnedArg(_ x2: __owned EnumTy) {
    let y2 = x2
    let k2 = y2
    borrowVal(k2)
}

public func enumSimpleNonConsumingUseTest(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
}

public func enumSimpleNonConsumingUseTestArg(_ x2: EnumTy) {
    borrowVal(x2)
}

public func enumSimpleNonConsumingUseTestOwnedArg(_ x2: __owned EnumTy) {
    borrowVal(x2)
}

public func enumMultipleNonConsumingUseTest(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func enumMultipleNonConsumingUseTestArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumMultipleNonConsumingUseTestOwnedArg(_ x2: __owned EnumTy) {
    borrowVal(x2)
    borrowVal(x2)
    consumeVal(x2)
}

public func enumUseAfterConsume(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumUseAfterConsumeArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumUseAfterConsumeOwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
    borrowVal(x2)
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumDoubleConsume(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x  // expected-error {{'x2' consumed more than once}}
                // expected-note @-1 {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumDoubleConsumeArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumDoubleConsumeOwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func enumLoopConsume(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-note @-1 {{consuming use here}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}}
    }
}

public func enumLoopConsumeArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func enumLoopConsumeOwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
        consumeVal(x2) // expected-note {{consuming in loop use here}};
    }
}

public func enumDiamond(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func enumDiamondArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    if boolValue {
        consumeVal(x2) // expected-note {{consuming use here}}
    } else {
        consumeVal(x2) // expected-note {{consuming use here}}
    }
}

public func enumDiamondOwnedArg(_ x2: __owned EnumTy) {
    if boolValue {
        consumeVal(x2)
    } else {
        consumeVal(x2)
    }
}

public func enumDiamondInLoop(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func enumDiamondInLoopArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
      }
    }
}

public func enumDiamondInLoopOwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
    // expected-error @-1 {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
      if boolValue {
          consumeVal(x2) // expected-note {{consuming use here}}
      } else {
          consumeVal(x2) // expected-note {{consuming use here}}
          // expected-note @-1 {{consuming in loop use here}}
      }
    }
}

public func enumAssignToVar1(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar1Arg(_ x: EnumTy, _ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
                                                             // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar1OwnedArg(_ x: EnumTy, _ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
                                                                          // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar2(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x3)
}

public func enumAssignToVar2Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x3)
}

public func enumAssignToVar2OwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x3)
}

public func enumAssignToVar3(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    var x3 = x2
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar3Arg(_ x: EnumTy, _ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
                                                             // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar3OwnedArg(_ x: EnumTy, _ x2: __owned EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar4(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar4Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar4OwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
    let x3 = x2 // expected-note {{consuming use here}}
    consumeVal(x2) // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar5(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' used after consume}}
               // expected-note @-1 {{consuming use here}}
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar5Arg(_ x: EnumTy, _ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
                                                             // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    // TODO: Need to mark this as the lifetime extending use. We fail
    // appropriately though.
    borrowVal(x2)
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumAssignToVar5OwnedArg(_ x: EnumTy, _ x2: __owned EnumTy) { // expected-error {{'x2' used after consume}}
                                                                          // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    var x3 = x2 // expected-note {{consuming use here}}
    borrowVal(x2) // expected-note {{non-consuming use here}}
    x3 = x // expected-note {{consuming use here}}
    consumeVal(x3)
}

public func enumPatternMatchIfLet1(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
    if case let .klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x.i)
    }
    if case let .klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x.i)
    }
}

public func enumPatternMatchIfLet1Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    if case let .klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x.i)
    }
    if case let .klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x.i)
    }
}

public func enumPatternMatchIfLet1OwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed more than once}}
    if case let .klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x)
    }
    if case let .klass(x) = x2 { // expected-note {{consuming use here}}
        borrowVal(x)
    }
}

public func enumPatternMatchIfLet2(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed by a use in a loop}}
               // expected-note @-1 {{consuming use here}}
    for _ in 0..<1024 {
        if case let .klass(x) = x2 {  // expected-note {{consuming in loop use here}}
            borrowVal(x)
        }
    }
}

public func enumPatternMatchIfLet2Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    for _ in 0..<1024 {
        if case let .klass(x) = x2 {  // expected-note {{consuming use here}}
            borrowVal(x)
        }
    }
}

public func enumPatternMatchIfLet2OwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' consumed by a use in a loop}}
    for _ in 0..<1024 {
        if case let .klass(x) = x2 {  // expected-note {{consuming in loop use here}}
            borrowVal(x)
        }
    }
}

// TODO: This is wrong.
public func enumPatternMatchSwitch1(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' used after consume}}
               // expected-note @-1 {{consuming use here}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k):
        borrowVal(k)
        borrowVal(x2) // expected-note {{non-consuming use here}}
    case .int:
        break
    }
}

public func enumPatternMatchSwitch1Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k):
        borrowVal(k)
        // This should be flagged as the use after free use. We are atleast
        // erroring though.
        borrowVal(x2)
    case .int:
        break
    }
}

public func enumPatternMatchSwitch1OwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' used after consume}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k):
        borrowVal(k)
        borrowVal(x2) // expected-note {{non-consuming use here}}
    case .int:
        break
    }
}

public func enumPatternMatchSwitch2(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    switch x2 {
    case let .klass(k):
        borrowVal(k)
    case .int:
        break
    }
}

public func enumPatternMatchSwitch2Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k):
        borrowVal(k)
    case .int:
        break
    }
}

public func enumPatternMatchSwitch2OwnedArg(_ x2: __owned EnumTy) {
    switch x2 {
    case let .klass(k):
        borrowVal(k)
    case .int:
        break
    }
}

// TODO: We can do better here. We should also flag x2
public func enumPatternMatchSwitch2WhereClause(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' used after consume}}
               // expected-note @-1 {{consuming use here}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k)
           where x2.doSomething(): // expected-note {{non-consuming use here}}
        borrowVal(k)
    case .int:
        break
    case .klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClauseArg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k)
           where x2.doSomething():
        borrowVal(k)
    case .int:
        break
    case .klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClauseOwnedArg(_ x2: __owned EnumTy) { // expected-error {{'x2' used after consume}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k)
           where x2.doSomething(): // expected-note {{non-consuming use here}}
        borrowVal(k)
    case .int:
        break
    case .klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClause2(_ x: EnumTy) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    switch x2 {
    case let .klass(k)
           where boolValue:
        borrowVal(k)
    case .int:
        break
    case .klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClause2Arg(_ x2: EnumTy) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    switch x2 { // expected-note {{consuming use here}}
    case let .klass(k)
           where boolValue:
        borrowVal(k)
    case .int:
        break
    case .klass:
        break
    }
}

public func enumPatternMatchSwitch2WhereClause2OwnedArg(_ x2: __owned EnumTy) {
    switch x2 {
    case let .klass(k)
           where boolValue:
        borrowVal(k)
    case .int:
        break
    case .klass:
        break
    }
}

/////////////////////////////
// Closure and Defer Tests //
/////////////////////////////

public func closureClassUseAfterConsume1(_ x: NonTrivialStruct) {
    // expected-error @-1 {{'x' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-2 {{'x' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = { // expected-note {{closure capture here}}
        let x2 = x // expected-error {{'x2' consumed more than once}}
        // expected-note @-1 {{consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
}

public func closureClassUseAfterConsume2(_ argX: NonTrivialStruct) {
    let f = { (_ x: NonTrivialStruct) in // expected-error {{'x' has guaranteed ownership but was consumed}}
        let x2 = x // expected-error {{'x2' consumed more than once}}
                   // expected-note @-1 {{consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f(argX)
}

public func closureClassUseAfterConsumeArg(_ argX: NonTrivialStruct) {
    // TODO: Fix this
    let f = { (_ x2: NonTrivialStruct) in // expected-error {{'x2' has guaranteed ownership but was consumed}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f(argX)
}

public func closureCaptureClassUseAfterConsume(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = {
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
}

public func closureCaptureClassUseAfterConsumeError(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = { // expected-note {{consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
    let x3 = x2 // expected-note {{consuming use here}}
    let _ = x3
}

public func closureCaptureClassArgUseAfterConsume(_ x2: NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-2 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = { // expected-note {{closure capture here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
}

public func closureCaptureClassOwnedArgUseAfterConsume(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = {
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
}

public func closureCaptureClassOwnedArgUseAfterConsume2(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = { // expected-note {{consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    f()
    let x3 = x2 // expected-note {{consuming use here}}
    let _ = x3
}

public func deferCaptureClassUseAfterConsume(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    defer {
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    consumeVal(x) // expected-note {{consuming use here}}
}

public func deferCaptureClassUseAfterConsume2(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' used after consume}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    defer { // expected-note {{non-consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    let x3 = x2 // expected-note {{consuming use here}}
    let _ = x3
}

public func deferCaptureClassArgUseAfterConsume(_ x2: NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    borrowVal(x2)
    defer {
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    consumeVal("foo")
}

public func deferCaptureClassOwnedArgUseAfterConsume(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    defer {
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    consumeVal("foo")
}

public func deferCaptureClassOwnedArgUseAfterConsume2(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' used after consume}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    defer { // expected-note {{non-consuming use here}}
        borrowVal(x2)
        consumeVal(x2) // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
    }
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func closureAndDeferCaptureClassUseAfterConsume(_ x: NonTrivialStruct) {
    // expected-error @-1 {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = {
        defer {
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        consumeVal("foo")
    }
    f()
}

public func closureAndDeferCaptureClassUseAfterConsume2(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = {
        consumeVal(x2) // expected-note {{consuming use here}}
        defer {
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        consumeVal("foo")
    }
    f()
}

public func closureAndDeferCaptureClassUseAfterConsume3(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
    // expected-note @-1 {{consuming use here}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-3 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = { // expected-note {{consuming use here}}
        consumeVal(x2) // expected-note {{consuming use here}}
        defer {
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        consumeVal("foo")
    }
    f()
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func closureAndDeferCaptureClassArgUseAfterConsume(_ x2: NonTrivialStruct) { // expected-error {{'x2' has guaranteed ownership but was consumed}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = { // expected-note {{closure capture here}}
        defer {
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        consumeVal("foo")
    }
    f()
}

public func closureAndDeferCaptureClassOwnedArgUseAfterConsume(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = {
        defer {
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        consumeVal("foo")
    }
    f()
}

public func closureAndDeferCaptureClassOwnedArgUseAfterConsume2(_ x2: __owned NonTrivialStruct) { // expected-error {{'x2' consumed more than once}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    let f = { // expected-note {{consuming use here}}
        defer {
            borrowVal(x2)
            consumeVal(x2) //  expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        consumeVal("foo")
    }
    f()
    consumeVal(x2) // expected-note {{consuming use here}}
}

public func closureAndClosureCaptureClassUseAfterConsume(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-note {{consuming use here}}
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-2 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = {
        let g = { // expected-note {{closure capture here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        g()
    }
    f()
}

public func closureAndClosureCaptureClassUseAfterConsume2(_ x: NonTrivialStruct) { // expected-error {{'x' has guaranteed ownership but was consumed}}
    let x2 = x // expected-error {{'x2' consumed more than once}}
               // expected-note @-1 {{consuming use here}}
               // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
               // expected-error @-3 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = { // expected-note {{consuming use here}}
        let g = { // expected-note {{closure capture here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        g()
    }
    f()
    consumeVal(x2) // expected-note {{consuming use here}}
}


public func closureAndClosureCaptureClassArgUseAfterConsume(_ x2: NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-2 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    // expected-error @-3 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = { // expected-note {{closure capture here}}
        let g = { // expected-note {{closure capture here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        g()
    }
    f()
}

public func closureAndClosureCaptureClassOwnedArgUseAfterConsume(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-2 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = {
        let g = { // expected-note {{closure capture here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        g()
    }
    f()
}

public func closureAndClosureCaptureClassOwnedArgUseAfterConsume2(_ x2: __owned NonTrivialStruct) {
    // expected-error @-1 {{'x2' consumed more than once}}
    // expected-error @-2 {{'x2' consumed in closure. This is illegal since if the closure is invoked more than once the binding will be uninitialized on later invocations}}
    // expected-error @-3 {{'x2' has guaranteed ownership but was consumed due to being captured by a closure}}
    let f = { // expected-note {{consuming use here}}
        let g = { // expected-note {{closure capture here}}
            borrowVal(x2)
            consumeVal(x2) // expected-note {{consuming use here}}
            consumeVal(x2) // expected-note {{consuming use here}}
        }
        g()
    }
    f()
    consumeVal(x2) // expected-note {{consuming use here}}
}
