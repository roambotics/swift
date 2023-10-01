// RUN: %target-typecheck-verify-swift -disable-availability-checking

// Generic parameter packs cannot witness associated type requirements
protocol HasAssoc {
  associatedtype A
  // expected-note@-1 {{protocol requires nested type 'A'; add nested type 'A' for conformance}}
}

struct HasPack<each A>: HasAssoc {}
// expected-error@-1 {{type 'HasPack<repeat each A>' does not conform to protocol 'HasAssoc'}}

protocol P {}

protocol HasPackRequirements {
  func doStuff1<each U: P>(_ value: repeat each U) -> (repeat Array<each U>)
  func doStuff2<each U: P>(_ value: repeat each U) -> (repeat Array<each U>)
}

extension HasPackRequirements {
  func doStuff1<each U: P>(_ value: repeat each U) -> (repeat Array<each U>) {
    return (repeat [each value])
  }
}

struct ConformsPackRequirements<each T>: HasPackRequirements {
  func doStuff2<each U: P>(_ value: repeat each U) -> (repeat Array<each U>) {
    return (repeat [each value])
  }
}


