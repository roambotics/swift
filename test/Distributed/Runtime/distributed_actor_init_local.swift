// RUN: %target-run-simple-swift(-Xfrontend -enable-experimental-distributed -Xfrontend -disable-availability-checking -parse-as-library) | %FileCheck %s

// REQUIRES: executable_test
// REQUIRES: concurrency
// REQUIRES: distributed

// rdar://76038845
// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

// REQUIRES: radar_86543336

import _Distributed

enum MyError: Error {
  case test
}

distributed actor PickATransport1 {
  init(kappa system: FakeActorSystem, other: Int) {}
}

distributed actor PickATransport2 {
  init(other: Int, thesystem: FakeActorSystem) async {}
}

distributed actor LocalWorker {
  init(system: FakeActorSystem) {}
}

distributed actor Bug_CallsReadyTwice {
  var x: Int
  init(system: FakeActorSystem, wantBug: Bool) async {
    if wantBug {
      self.x = 1
    }
    self.x = 2
  }
}

distributed actor Throwy {
  init(system: FakeActorSystem, doThrow: Bool) throws {
    if doThrow {
      throw MyError.test
    }
  }
}

distributed actor ThrowBeforeFullyInit {
  var x: Int
  init(system: FakeActorSystem, doThrow: Bool) throws {
    if doThrow {
      throw MyError.test
    }
    self.x = 0
  }
}

// ==== Fake Transport ---------------------------------------------------------

struct ActorAddress: Sendable, Hashable, Codable {
  let address: String
  init(parse address: String) {
    self.address = address
  }
}

// global to track available IDs
var nextID: Int = 1

struct FakeActorSystem: DistributedActorSystem {
  public typealias ActorID = ActorAddress
  public typealias InvocationDecoder = FakeInvocationDecoder
  public typealias InvocationEncoder = FakeInvocationEncoder
  public typealias SerializationRequirement = Codable

  init() {
    print("Initialized new FakeActorSystem")
  }

  public func resolve<Act>(id: ActorID, as actorType: Act.Type) throws -> Act?
      where Act: DistributedActor,
            Act.ID == ActorID  {
    fatalError("not implemented:\(#function)")
  }

  func assignID<Act>(_ actorType: Act.Type) -> ActorID
      where Act: DistributedActor {
    let id = ActorAddress(parse: "\(nextID)")
    nextID += 1
    print("assign type:\(actorType), id:\(id)")
    return id
  }

  func actorReady<Act>(_ actor: Act)
      where Act: DistributedActor,
      Act.ID == ActorID {
    print("ready actor:\(actor), id:\(actor.id)")
  }

  func resignID(_ id: ActorID) {
    print("resign id:\(id)")
  }

  func makeInvocationEncoder() -> InvocationEncoder {
    .init()
  }

  func remoteCall<Act, Err, Res>(
      on actor: Act,
      target: RemoteCallTarget,
      invocation: inout InvocationDecoder,
      throwing: Err.Type,
      returning: Res.Type
  ) async throws -> Res
      where Act: DistributedActor,
            Act.ID == ActorID,
            Res: SerializationRequirement {
    throw ExecuteDistributedTargetError(message: "Not implemented")
  }

}

// === Sending / encoding -------------------------------------------------
struct FakeInvocationEncoder: DistributedTargetInvocationEncoder {
  typealias SerializationRequirement = Codable

  mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {}
  mutating func recordArgument<Argument: SerializationRequirement>(_ argument: Argument) throws {}
  mutating func recordReturnType<R: SerializationRequirement>(_ type: R.Type) throws {}
  mutating func recordErrorType<E: Error>(_ type: E.Type) throws {}
  mutating func doneRecording() throws {}
}

// === Receiving / decoding -------------------------------------------------
class FakeInvocationDecoder : DistributedTargetInvocationDecoder {
  typealias SerializationRequirement = Codable

  func decodeGenericSubstitutions() throws -> [Any.Type] { [] }
  func decodeNextArgument<Argument: SerializationRequirement>() throws -> Argument { fatalError() }
  func decodeReturnType() throws -> Any.Type? { nil }
  func decodeErrorType() throws -> Any.Type? { nil }
}

typealias DefaultDistributedActorSystem = FakeActorSystem

// ==== Execute ----------------------------------------------------------------

func test() async {
  let system = DefaultDistributedActorSystem()

  // NOTE: All allocated distributed actors should be saved in this array, so
  // that they will be deallocated together at the end of this test!
  // This convention helps ensure that the test is not flaky.
  var test: [DistributedActor?] = []

  test.append(LocalWorker(system: system))
  // CHECK: assign type:LocalWorker, id:ActorAddress(address: "[[ID1:.*]]")
  // CHECK: ready actor:main.LocalWorker, id:ActorAddress(address: "[[ID1]]")

  test.append(PickATransport1(kappa: system, other: 0))
  // CHECK: assign type:PickATransport1, id:ActorAddress(address: "[[ID2:.*]]")
  // CHECK: ready actor:main.PickATransport1, id:ActorAddress(address: "[[ID2]]")

  test.append(try? Throwy(system: system, doThrow: false))
  // CHECK: assign type:Throwy, id:ActorAddress(address: "[[ID3:.*]]")
  // CHECK: ready actor:main.Throwy, id:ActorAddress(address: "[[ID3]]")

  test.append(try? Throwy(system: system, doThrow: true))
  // CHECK: assign type:Throwy, id:ActorAddress(address: "[[ID4:.*]]")
  // CHECK-NOT: ready

  test.append(try? ThrowBeforeFullyInit(system: system, doThrow: true))
  // CHECK: assign type:ThrowBeforeFullyInit, id:ActorAddress(address: "[[ID5:.*]]")
  // CHECK-NOT: ready

  test.append(await PickATransport2(other: 1, thesystem: system))
  // CHECK: assign type:PickATransport2, id:ActorAddress(address: "[[ID6:.*]]")
  // CHECK: ready actor:main.PickATransport2, id:ActorAddress(address: "[[ID6]]")

  test.append(await Bug_CallsReadyTwice(system: system, wantBug: true))
    // CHECK: assign type:Bug_CallsReadyTwice, id:ActorAddress(address: "[[ID7:.*]]")
    // CHECK:      ready actor:main.Bug_CallsReadyTwice, id:ActorAddress(address: "[[ID7]]")
    // CHECK-NEXT: ready actor:main.Bug_CallsReadyTwice, id:ActorAddress(address: "[[ID7]]")

  // CHECK-DAG: resign id:ActorAddress(address: "[[ID1]]")
  // CHECK-DAG: resign id:ActorAddress(address: "[[ID2]]")
  // CHECK-DAG: resign id:ActorAddress(address: "[[ID3]]")
  // MISSING-CHECK-DAG: resign id:ActorAddress(address: "[[ID4]]") // FIXME: should eventually work (rdar://84533820).
  // MISSING-CHECK-DAG: resign id:ActorAddress(address: "[[ID5]]") // FIXME: should eventually work (rdar://84533820).
  // CHECK-DAG: resign id:ActorAddress(address: "[[ID6]]")
  // CHECK-DAG: resign id:ActorAddress(address: "[[ID7]]")
}

@main struct Main {
  static func main() async {
    await test()
  }
}
