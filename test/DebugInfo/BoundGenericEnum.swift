// RUN: %target-swift-frontend %s -O -emit-ir -g -o %t.ll -module-name a 
// RUN: cat %t.ll | %FileCheck %s --check-prefix=CASE_0
// RUN: cat %t.ll | %FileCheck %s --check-prefix=CASE_1
// RUN: cat %t.ll | %FileCheck %s --check-prefix=CASE_2
public enum Result<Value> {
  case success(Value)
  case failure(Error)
}

extension Result {
  public func map<U>(_ transform: (Value) -> U) -> Result<U> {
    switch self {
    case .success(let value):
      return .success(transform(value))
    case .failure(let error):
      return .failure(error)
    }
  }
}

@inline(never)
func use<T>(_ t : T) {
  print(t)
}

public class SomeClass {
  public let s = "hello"
}

extension Result where Value : SomeClass {
  public func f() -> Self {
    use(self)
    return map({ $0 })
  }  
}

extension Result {
  public func g() {
    use(self)
  }  
}

let x : Result<SomeClass> = .success(SomeClass())
let y : Result<(Int64, Int64, Int64, Int64)> = .success((1, 2, 3, 4))
x.f()
y.g()

// Here we have three types, all named $s1a6ResultOyxGD (---> a.Result<A>),
// but with different storage sizes:
//
//   0. Unsized from the subroutine tupe of map<U>.
//   1. Enum wrapping a pointer-sized object [map() and f()].
//   2. Enum wrapping a 4x64-bit tuple.
//
// Test that bound generic enums are *not* using their mangled name as a unique
// identifier.

// (0) unsized.
// CASE_0-DAG: !DISubprogram(name: "map", {{.*}}line: 11, type: ![[SBTY:[0-9]+]]
// CASE_0-DAG: ![[SBTY]] = !DISubroutineType(types: ![[SBTYS:[0-9]+]])
// CASE_0-DAG: ![[SBTYS]] = !{!{{[0-9]+}}, !{{[0-9]+}}, ![[SELFTY:[0-9]+]]}
// CASE_0-DAG: ![[SELFTY]] = !DICompositeType(tag: DW_TAG_structure_type, {{.*}}line: 5, {{.*}}elements: ![[UNSIZED_ELTS:[0-9]+]]
// CASE_0-DAG: ![[UNSIZED_ELTS]] = !{![[UNSIZED_MEM:[0-9]+]]}
// CASE_0-DAG: ![[UNSIZED_MEM]] = !DIDerivedType(tag: DW_TAG_member, {{.*}} baseType: ![[UNIQ:[0-9]+]]

// The unique unsized type.
// CASE_0: ![[UNIQ]] = !DICompositeType(
// CASE_0-SAME:            tag: DW_TAG_structure_type, name: "Result",
// CASE_0-SAME:            line: 5,
// CASE_0-NOT:             size:
// CASE_0-SAME:            runtimeLang: DW_LANG_Swift,
// CASE_0-SAME:            identifier: "$s1a6ResultOyxGD")

// (1)
// CASE_1-DAG: ![[F:[0-9]+]] = distinct !DISubprogram(name: "f", 
// CASE_1-DAG: !DILocalVariable(name: "self", arg: 1, scope: ![[F]],{{.*}} line: 31,{{.*}} type: ![[C_CLASS:[0-9]+]]
// CASE_1-DAG: ![[C_CLASS]] = !DIDerivedType(tag: DW_TAG_const_type,{{.*}} baseType: ![[CLASS:[0-9]+]])
// CASE_1-DAG: ![[CLASS]] = !DICompositeType(tag: DW_TAG_structure_type,{{.*}} line: 5, size: {{40|72}}

// (2)
// CASE_2-DAG: ![[G:[0-9]+]] = distinct !DISubprogram(name: "g", 
// CASE_2-DAG: !DILocalVariable(name: "self", arg: 1, scope: ![[G]],{{.*}} line: 38,{{.*}} type: ![[C_TUP:[0-9]+]]
// CASE_2-DAG: ![[C_TUP]] = !DIDerivedType(tag: DW_TAG_const_type,{{.*}} baseType: ![[TUP:[0-9]+]])
// CASE_2-DAG: ![[TUP]] = !DICompositeType(tag: DW_TAG_structure_type,{{.*}} line: 5, size: {{264|512}},
