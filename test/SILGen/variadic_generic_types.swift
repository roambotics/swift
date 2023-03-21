// RUN: %target-swift-emit-silgen %s -enable-experimental-feature VariadicGenerics

// Because of -enable-experimental-feature VariadicGenerics
// REQUIRES: asserts

struct Variadic<each T> where each T: Equatable {}

_ = Variadic<Int, String>()
