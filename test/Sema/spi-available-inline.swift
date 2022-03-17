// REQUIRES: VENDOR=apple
// RUN: %target-typecheck-verify-swift -target x86_64-apple-macosx11.9

@_spi_available(macOS 10.4, *)
public class MacOSSPIClass { public init() {} }

@_spi_available(iOS 8.0, *)
public class iOSSPIClass { public init() {} }

@inlinable public func foo() {
	_ = MacOSSPIClass() // expected-error {{class 'MacOSSPIClass' cannot be used in an '@inlinable' function because it is SPI}}
	_ = iOSSPIClass()
}
