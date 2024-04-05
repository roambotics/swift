// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend -emit-module -emit-module-path %t/OtherActors.swiftmodule -module-name OtherActors %S/Inputs/OtherActors.swift -disable-availability-checking

// RUN: %target-swift-frontend -I %t  -disable-availability-checking -strict-concurrency=complete -enable-upcoming-feature IsolatedDefaultValues -parse-as-library -emit-sil -o /dev/null -verify %s
// RUN: %target-swift-frontend -I %t  -disable-availability-checking -strict-concurrency=complete -parse-as-library -emit-sil -o /dev/null -verify -enable-upcoming-feature IsolatedDefaultValues -enable-upcoming-feature RegionBasedIsolation %s

// REQUIRES: concurrency
// REQUIRES: asserts

@globalActor
actor SomeGlobalActor {
  static let shared = SomeGlobalActor()
}

@MainActor
func requiresMainActor() -> Int { 0 }

@SomeGlobalActor
func requiresSomeGlobalActor() -> Int { 0 }

class C1 {
  // expected-note@+1 2 {{'self.x' not initialized}}
  @MainActor var x = requiresMainActor()
  // expected-note@+1 2 {{'self.y' not initialized}}
  @SomeGlobalActor var y = requiresSomeGlobalActor()
  var z = 10

  // expected-error@+1 {{return from initializer without initializing all stored properties}}
  nonisolated init(a: Int) {}

  // expected-error@+1 {{return from initializer without initializing all stored properties}}
  @MainActor init(b: Int) {}

  // expected-error@+1 {{return from initializer without initializing all stored properties}}
  @SomeGlobalActor init(c: Int) {}
}

class C2 {
  @MainActor var x = requiresMainActor()
  @SomeGlobalActor var y = requiresSomeGlobalActor()
  var z = 10

  nonisolated init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  @MainActor init(y: Int) {
    self.y = y
  }

  @SomeGlobalActor init(x: Int) {
    self.x = x
  }
}

