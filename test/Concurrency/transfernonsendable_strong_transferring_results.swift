// RUN: %target-swift-frontend -emit-sil -parse-as-library -strict-concurrency=complete -disable-availability-checking -enable-experimental-feature TransferringArgsAndResults -verify -enable-upcoming-feature RegionBasedIsolation %s -o /dev/null

// REQUIRES: concurrency
// REQUIRES: asserts

////////////////////////
// MARK: Declarations //
////////////////////////

class NonSendableKlass {} // expected-note {{}}

struct NonSendableStruct {
  var first = NonSendableKlass()
  var second = NonSendableKlass()
}

func getValue<T>() -> T { fatalError() }
func getValueAsync<T>() async -> T { fatalError() }
func getValueAsyncTransferring<T>() async -> transferring T { fatalError() }

func useValue<T>(_ t: T) {}
func getAny() -> Any { fatalError() }

actor Custom {
}

@globalActor
struct CustomActor {
    static var shared: Custom {
        return Custom()
    }
}

@MainActor func transferToMainIndirect<T>(_ t: T) async {}
@CustomActor func transferToCustomIndirect<T>(_ t: T) async {}
@MainActor func transferToMainDirect(_ t: NonSendableKlass) async {}
@CustomActor func transferToCustomDirect(_ t: NonSendableKlass) async {}
func useValueIndirect<T>(_ t: T) {}
func useValueDirect(_ t: NonSendableKlass) {}

func transferValueDirect(_ x: transferring NonSendableKlass) {}
func transferValueIndirect<T>(_ x: transferring T) {}

func transferResult() -> transferring NonSendableKlass { NonSendableKlass() }
func transferResultWithArg(_ x: NonSendableKlass) -> transferring NonSendableKlass { NonSendableKlass() }
func transferResultWithTransferringArg(_ x: transferring NonSendableKlass) -> transferring NonSendableKlass { NonSendableKlass() }
func transferResultWithTransferringArg2(_ x: transferring NonSendableKlass, _ y: NonSendableKlass) -> transferring NonSendableKlass { NonSendableKlass() }
func transferResultWithTransferringArg2Throwing(_ x: transferring NonSendableKlass, _ y: NonSendableKlass) throws -> transferring NonSendableKlass { NonSendableKlass() }

func transferAsyncResult() async -> transferring NonSendableKlass { NonSendableKlass() }
func transferAsyncResultWithArg(_ x: NonSendableKlass) async -> transferring NonSendableKlass { NonSendableKlass() }
func transferAsyncResultWithTransferringArg(_ x: transferring NonSendableKlass) async -> transferring NonSendableKlass { NonSendableKlass() }
func transferAsyncResultWithTransferringArg2(_ x: transferring NonSendableKlass, _ y: NonSendableKlass) async -> transferring NonSendableKlass { NonSendableKlass() }
func transferAsyncResultWithTransferringArg2Throwing(_ x: transferring NonSendableKlass, _ y: NonSendableKlass) async throws -> transferring NonSendableKlass { NonSendableKlass() }

@MainActor func transferAsyncResultMainActor() async -> transferring NonSendableKlass { NonSendableKlass() }

@MainActor var globalNonSendableKlass = NonSendableKlass()

@MainActor
struct MainActorIsolatedStruct {
  let ns = NonSendableKlass()
}

@MainActor
enum MainActorIsolatedEnum {
  case first
  case second(NonSendableKlass)
}

/////////////////
// MARK: Tests //
/////////////////

func simpleTest() async {
  let x = NonSendableKlass()
  let y = transferResultWithArg(x)
  await transferToMainDirect(x)
  useValue(y)
}

// Since y is transfered, we should emit the error on useValue(x). We generally
// emit the first seen error on a path, so if we were to emit an error on
// useValue(y), we would have emitted that error.
func simpleTest2() async {
  let x = NonSendableKlass()
  let y = transferResultWithArg(x)
  await transferToMainDirect(x) // expected-warning {{transferring 'x' may cause a race}}
  // expected-note @-1 {{transferring disconnected 'x' to main actor-isolated callee could cause races in between callee main actor-isolated and local nonisolated uses}}
  useValue(y)
  useValue(x) // expected-note {{use here could race}}
}

// Make sure that later errors with y can happen.
func simpleTest3() async {
  let x = NonSendableKlass()
  let y = transferResultWithArg(x)
  await transferToMainDirect(x)
  await transferToMainDirect(y) // expected-warning {{transferring 'y' may cause a race}}
  // expected-note @-1 {{transferring disconnected 'y' to main actor-isolated callee could cause races in between callee main actor-isolated and local nonisolated uses}}
  useValue(y) // expected-note {{use here could race}}
}

func transferResult() async -> transferring NonSendableKlass {
  let x = NonSendableKlass()
  await transferToMainDirect(x) // expected-warning {{transferring 'x' may cause a race}}
  // expected-note @-1 {{transferring disconnected 'x' to main actor-isolated callee could cause races in between callee main actor-isolated and local nonisolated uses}}
  return x // expected-note {{use here could race}}
}

func transferInAndOut(_ x: transferring NonSendableKlass) -> transferring NonSendableKlass {
  x
}


func transferReturnArg(_ x: NonSendableKlass) -> transferring NonSendableKlass {
  return x // expected-warning {{transferring 'x' may cause a race}}
  // expected-note @-1 {{task-isolated 'x' cannot be a transferring result. task-isolated uses may race with caller uses}}
}

// TODO: This will be fixed once I represent @MainActor on func types.
@MainActor func transferReturnArgMainActor(_ x: NonSendableKlass) -> transferring NonSendableKlass {
  return x // expected-warning {{transferring 'x' may cause a race}}
  // expected-note @-1 {{main actor-isolated 'x' cannot be a transferring result. main actor-isolated uses may race with caller uses}}
}

// This is safe since we are returning the whole tuple fresh. In contrast,
// (transferring NonSendableKlass, transferring NonSendableKlass) would not be
// safe if we ever support that.
func transferReturnArgTuple(_ x: transferring NonSendableKlass) -> transferring (NonSendableKlass, NonSendableKlass) {
  return (x, x)
}

func useTransferredResultMainActor() async {
  let _ = await transferAsyncResultMainActor()
}

func useTransferredResult() async {
  let _ = await transferAsyncResult()
}

extension MainActorIsolatedStruct {
  func testNonSendableErrorReturnWithTransfer() -> transferring NonSendableKlass {
    return ns // expected-warning {{transferring 'self.ns' may cause a race}}
    // expected-note @-1 {{main actor-isolated 'self.ns' cannot be a transferring result. main actor-isolated uses may race with caller uses}}
  }
  func testNonSendableErrorReturnNoTransfer() -> NonSendableKlass {
    return ns
  }
}

extension MainActorIsolatedEnum {
  func testSwitchReturn() -> transferring NonSendableKlass? {
    switch self {
    case .first:
      return nil
    case .second(let ns):
      return ns
    }
  } // expected-warning {{transferring 'ns.some' may cause a race}}
  // expected-note @-1 {{main actor-isolated 'ns.some' cannot be a transferring result. main actor-isolated uses may race with caller uses}}

  func testSwitchReturnNoTransfer() -> NonSendableKlass? {
    switch self {
    case .first:
      return nil
    case .second(let ns):
      return ns
    }
  }

  func testIfLetReturn() -> transferring NonSendableKlass? {
    if case .second(let ns) = self {
      return ns // TODO: The error below should be here.
    }
    return nil
  } // expected-warning {{transferring 'ns.some' may cause a race}}
  // expected-note @-1 {{main actor-isolated 'ns.some' cannot be a transferring result. main actor-isolated uses may race with caller uses}} 

  func testIfLetReturnNoTransfer() -> NonSendableKlass? {
    if case .second(let ns) = self {
      return ns
    }
    return nil
  }

}

///////////////////////////
// MARK: Async Let Tests //
///////////////////////////
//
// Move these tests to async let once strict-concurrency=complete requires
// transfer non sendable.

// Make sure that we can properly construct a reabstraction thunk since
// constructNonSendableKlassAsync doesn't return the value transferring but
// async let wants it to be transferring.
//
// Importantly, we should only emit the sema error here saying that one cannot
// return a non-Sendable value here.
func asyncLetReabstractionThunkTest() async {
  // With thunk.
  async let newValue: NonSendableKlass = await getValueAsync()
  let _ = await newValue

  // Without thunk.
  async let newValue2: NonSendableKlass = await getValueAsyncTransferring()
  let _ = await newValue2
}

@MainActor func asyncLetReabstractionThunkTestGlobalActor() async {
  // With thunk. We emit the sema error here.
  async let newValue: NonSendableKlass = await getValueAsync() // expected-warning {{non-sendable type 'NonSendableKlass' returned by implicitly asynchronous call to nonisolated function cannot cross actor boundary}}
  let _ = await newValue

  // Without thunk.
  async let newValue2: NonSendableKlass = await getValueAsyncTransferring()
  let _ = await newValue2
}


