// RUN: %target-swift-frontend -disable-availability-checking -enable-experimental-feature StrictConcurrency -emit-sil -o /dev/null -verify %s -disable-region-based-isolation-with-strict-concurrency
// RUN: %target-swift-frontend -disable-availability-checking -enable-experimental-feature StrictConcurrency=complete -emit-sil -o /dev/null -verify %s -disable-region-based-isolation-with-strict-concurrency
// RUN: %target-swift-frontend -disable-availability-checking -enable-upcoming-feature StrictConcurrency -emit-sil -o /dev/null -verify %s -disable-region-based-isolation-with-strict-concurrency
// RUN: %target-swift-frontend -disable-availability-checking -enable-upcoming-feature StrictConcurrency -emit-sil -o /dev/null -verify -verify-additional-prefix region-isolation- %s

// REQUIRES: concurrency
// REQUIRES: asserts

class C1 { } // expected-note{{class 'C1' does not conform to the 'Sendable' protocol}}
class C2 { }

@available(*, unavailable)
extension C2: Sendable {} // expected-note{{conformance of 'C2' to 'Sendable' has been explicitly marked unavailable here}}

protocol TestProtocol {
  associatedtype Value: Sendable
}

struct Test1: TestProtocol { // expected-warning{{type 'Test1.Value' (aka 'C1') does not conform to the 'Sendable' protocol}}
  typealias Value = C1
}

struct Test2: TestProtocol { // expected-warning{{conformance of 'C2' to 'Sendable' is unavailable}}
  // expected-note@-1{{in associated type 'Self.Value' (inferred as 'C2')}}
  typealias Value = C2
}

@MainActor
func iterate(stream: AsyncStream<Int>) async {
  nonisolated(unsafe) var it = stream.makeAsyncIterator()
  // FIXME: Region isolation should consider a value from a 'nonisolated(unsafe)'
  // declaration to be in a disconnected region

  // expected-region-isolation-warning @+3 {{transferring 'it' may cause a race}}
  // expected-region-isolation-note @+2 {{transferring disconnected 'it' to nonisolated callee could cause races in between callee nonisolated and local main actor-isolated uses}}
  // expected-region-isolation-note @+1 {{use here could race}}
  while let element = await it.next() {
    print(element)
  }

  for await x in stream {
    print(x)
  }
}
