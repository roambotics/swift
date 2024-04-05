// RUN: %target-swift-frontend -swift-version 6 -disable-availability-checking -emit-sil -o /dev/null %s -parse-as-library -enable-experimental-feature TransferringArgsAndResults -verify -import-objc-header %S/Inputs/transferring.h

// REQUIRES: concurrency
// REQUIRES: asserts
// REQUIRES: objc_interop

////////////////////////
// MARK: Declarations //
////////////////////////

@MainActor func transferToMain<T>(_ t: T) async {}
func useValue<T>(_ t: T) {}

/////////////////
// MARK: Tests //
/////////////////

func methodTestTransferringResult() async {
  let x = MyType()
  let y = x.getTransferringResult()
  await transferToMain(x)
  useValue(y)
}

func methodTestTransferringArg() async {
  let x = MyType()
  let s = NSObject()
  let _ = x.getResultWithTransferringArgument(s)  // expected-error {{transferring 's' may cause a race}}
  // expected-note @-1 {{'s' used after being passed as a transferring parameter; Later uses could race}}
  useValue(s) // expected-note {{use here could race}}
}

// Make sure we just ignore the swift_attr if it is applied to something like a
// class.
func testDoesntMakeSense() {
  let _ = DoesntMakeSense()
}

func funcTestTransferringResult() async {
  let x = NSObject()
  let y = transferNSObjectFromGlobalFunction(x)
  await transferToMain(x)
  useValue(y)

  // Just to show that without the transferring param, we generate diagnostics.
  let x2 = NSObject()
  let y2 = returnNSObjectFromGlobalFunction(x2)
  await transferToMain(x2) // expected-error {{transferring 'x2' may cause a race}}
  // expected-note @-1 {{transferring disconnected 'x2' to main actor-isolated callee could cause races in between callee main actor-isolated and local nonisolated uses}}
  useValue(y2) // expected-note {{use here could race}}
}

func funcTestTransferringArg() async {
  let x = NSObject()
  transferNSObjectToGlobalFunction(x) // expected-error {{transferring 'x' may cause a race}}
  // expected-note @-1 {{'x' used after being passed as a transferring parameter; Later uses could race}}
  useValue(x) // expected-note {{use here could race}}
}
