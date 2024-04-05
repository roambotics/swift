// RUN: %target-typecheck-verify-swift -enable-builtin-module \
// RUN:   -parse-stdlib -module-name Ghost \
// RUN:   -enable-experimental-feature NoncopyableGenerics



// This test covers only rudimentary typechecking when only the Builtin module
// is available. It's not a fully-supported configuration!

import Builtin

func reqCopy1<T>(_ t: T) {} // expected-note {{generic parameter 'T' has an implicit Copyable requirement}}
func reqCopy2<T: Builtin.Copyable>(_ t: T) {} // expected-note {{generic parameter 'T' has an implicit Copyable requirement}}

protocol P {}

struct DataType: P, Builtin.Escapable {}
struct DataTypeNC: ~Builtin.Copyable {}

func main() {
    reqCopy1(DataTypeNC()) // expected-error {{noncopyable type 'DataTypeNC' cannot be substituted for copyable generic parameter 'T' in 'reqCopy1'}}
    reqCopy2(DataTypeNC()) // expected-error {{noncopyable type 'DataTypeNC' cannot be substituted for copyable generic parameter 'T' in 'reqCopy2'}}
    reqCopy1(DataType())
    reqCopy2(DataType())
}
