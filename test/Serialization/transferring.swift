// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -strict-concurrency=complete -enable-upcoming-feature RegionBasedIsolation -enable-experimental-feature TransferringArgsAndResults -module-name transferring_test -emit-module -o %t/transferring_test.swiftmodule %S/Inputs/transferring.swift
// RUN: %target-swift-frontend -strict-concurrency=complete -enable-upcoming-feature RegionBasedIsolation -enable-experimental-feature TransferringArgsAndResults -emit-sil -I %t %s | %FileCheck %s
// RUN: %target-sil-opt -strict-concurrency=complete -enable-upcoming-feature RegionBasedIsolation -enable-experimental-feature TransferringArgsAndResults %t/transferring_test.swiftmodule | %FileCheck -check-prefix=AST %s

// REQUIRES: concurrency
// REQUIRES: asserts

// READ THIS!
//
// This test is meant to test serialization of transferring declarations in the
// AST.

import transferring_test

func main() {
  let x = "123"
  let y = test(x)
}

// CHECK-LABEL: sil @$s17transferring_test0B0yS2SnYuYTF : $@convention(thin) (@sil_transferring @owned String) -> @sil_transferring @owned String

// AST-LABEL: func test(_ x: transferring String) -> transferring String
