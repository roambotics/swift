// These are purely to add test coverage of different constructs when emitting modules

public protocol _NoCopyP: ~Copyable {}
public protocol _NoEscapableP: ~Escapable {}

extension Int: _NoCopyP {}

public struct _Toys {
  static func test_parallelAssignment() {
    var y: Int
    var x: Int
    (x, y) = (10, 11)
  }

  public struct rdar118697289_S1<Element> {
    let element: Element
    func f() -> Element { element }
  }

  public struct rdar118697289_S2<Element> {
      let element: Element
      subscript(i: Int) -> Element {
          element
      }
  }

  public static func allCopyable1<T>(_ a: T, _ b: T) -> T { return a }

  public static func allCopyable2<T>(_ s: T)
                                  where T: _NoCopyP {}

  public static func oneCopyable1<T, V: ~Copyable>(_ s: T, _ v: borrowing V)
                                  where T: _NoCopyP {}

  public static func oneCopyable2<T, V>(_ s: borrowing T, _ v: V)
                                  where T: _NoCopyP, T: ~Copyable {}

  public static func oneCopyable3<T, V>(_ s: borrowing T, _ v: V)
                                  where T: _NoCopyP & ~Copyable {}

  public static func basic_some(_ s: some _NoCopyP) {}

  public static func basic_some_nc(_ s: borrowing some _NoCopyP & ~Copyable) {}

  public static func oneEscapable<T, V>(_ s: T, _ v: V)
                                    where T: _NoEscapableP, T: ~Escapable {}

  public static func canEscapeButConforms<T: _NoEscapableP>(_ t: T) {}

  public static func opaqueNonEscapable(_ s: some _NoEscapableP & ~Escapable) {}

  public static func opaqueEscapable(_ s: some _NoEscapableP) {}
}

public struct ExplicitHello<T: ~Copyable>: ~Copyable {
  let thing: T
}
extension ExplicitHello: Copyable {}

public struct Hello<T: ~Copyable>: ~Copyable, ~Escapable where T: ~Escapable {}

extension Hello: Escapable where T: ~Copyable {}
extension Hello: Copyable where T: ~Escapable {}

public protocol TestAssocTypes {
  associatedtype A: ~Copyable, _NoCopyP = Int
}

public typealias SomeAlias<G> = Hello<G>

public typealias AliasWithInverse<G> = Hello<G> where G: ~Copyable, G: ~Escapable

public struct RudePointer<T: ~Copyable>: Copyable {}

public class C {}

public func noInversesSTART() {}
public func checkAny<Result>(_ t: Result) where Result: Any {}
public func usingClassConstraint<Result>(arg: Result) -> Result? where Result: C { return arg }
public func withAnyObject<Result>(_ t: Result) where Result: AnyObject {}
public func noInversesEND() {}

public func checkAnyInv1<Result>(_ t: borrowing Result) where Result: Any & ~Copyable {}
public func checkAnyInv2<Result: Any>(_ t: borrowing Result) where Result: ~Copyable & ~Escapable {}
public func checkAnyObject<Result>(_ t: Result) where Result: AnyObject {}

// coverage for rdar://123281976
public struct Outer<A: ~Copyable>: ~Copyable {
  public func innerFn<B: ~Copyable>(_ b: borrowing B) {}
  public struct InnerStruct<C: ~Copyable>: ~Copyable {
    public func g<D>(_ d: borrowing D) where D: ~Copyable {}
  }
  public struct InnerVariation1<D: ~Copyable>: ~Copyable, ~Escapable {}
  public struct InnerVariation2<D: ~Escapable>: ~Copyable, ~Escapable {}
}

extension Outer: Copyable {}
extension Outer.InnerStruct: Copyable {}

extension Outer.InnerVariation1: Copyable {}
extension Outer.InnerVariation2: Escapable {}

extension Outer.InnerStruct {
    public func hello<T: ~Escapable>(_ t: T) {}
}

@_preInverseGenerics
public func old_swap<T: ~Copyable>(_ a: inout T, _ b: inout T) {}

@_preInverseGenerics
public func borrowsNoncopyable<T: ~Copyable>(_ t: borrowing T) {}

@_disallowFeatureSuppression(NoncopyableGenerics)
public func suppressesNoncopyableGenerics<T: ~Copyable>(_ t: borrowing T) {}
