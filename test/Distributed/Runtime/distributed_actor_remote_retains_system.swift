// RUN: %target-run-simple-swift(-Xfrontend -enable-experimental-distributed -Xfrontend -disable-availability-checking -parse-as-library) | %FileCheck %s

// REQUIRES: executable_test
// REQUIRES: concurrency
// REQUIRES: distributed

// rdar://76038845
// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

import _Distributed

distributed actor SomeSpecificDistributedActor {
  deinit {
    print("deinit \(self.id)")
  }
}

// ==== Fake Transport ---------------------------------------------------------

struct FakeActorID: Sendable, Hashable, Codable {
  let id: UInt64
}

enum FakeActorSystemError: DistributedActorSystemError {
  case unsupportedActorIdentity(Any)
}

struct ActorAddress: Sendable, Hashable, Codable {
  let address: String
  init(parse address : String) {
    self.address = address
  }
}

final class FakeActorSystem: DistributedActorSystem {
  typealias ActorID = ActorAddress
  typealias InvocationDecoder = FakeInvocation
  typealias InvocationEncoder = FakeInvocation
  typealias SerializationRequirement = Codable

  deinit {
    print("deinit \(self)")
  }

  func resolve<Act>(id: ActorID, as actorType: Act.Type)
  throws -> Act?
      where Act: DistributedActor {
    return nil
  }

  func assignID<Act>(_ actorType: Act.Type) -> ActorID
      where Act: DistributedActor {
    let id = ActorAddress(parse: "xxx")
    print("assignID type:\(actorType), id:\(id)")
    return id
  }

  func actorReady<Act>(_ actor: Act)
      where Act: DistributedActor,
      Act.ID == ActorID {
    print("actorReady actor:\(actor), id:\(actor.id)")
  }

  func resignID(_ id: ActorID) {
    print("assignID id:\(id)")
  }

  func makeInvocationEncoder() -> InvocationEncoder {
    .init()
  }

  func remoteCall<Act, Err, Res>(
    on actor: Act,
    target: RemoteCallTarget,
    invocation invocationEncoder: inout InvocationEncoder,
    throwing: Err.Type,
    returning: Res.Type
  ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error,
          Res: SerializationRequirement {
    fatalError("Not implemented")
  }

  func remoteCallVoid<Act, Err>(
    on actor: Act,
    target: RemoteCallTarget,
    invocation invocationEncoder: inout InvocationEncoder,
    throwing: Err.Type
  ) async throws
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error {
    fatalError("Not implemented")
  }
}

class FakeInvocation: DistributedTargetInvocationEncoder, DistributedTargetInvocationDecoder {
  typealias SerializationRequirement = Codable

  func recordGenericSubstitution<T>(_ type: T.Type) throws {}
  func recordArgument<Argument: SerializationRequirement>(_ argument: Argument) throws {}
  func recordReturnType<R: SerializationRequirement>(_ type: R.Type) throws {}
  func recordErrorType<E: Error>(_ type: E.Type) throws {}
  func doneRecording() throws {}

  // === Receiving / decoding -------------------------------------------------

  func decodeGenericSubstitutions() throws -> [Any.Type] { [] }
  func decodeNextArgument<Argument: SerializationRequirement>() throws -> Argument{ fatalError() }
  func decodeReturnType() throws -> Any.Type? { nil }
  func decodeErrorType() throws -> Any.Type? { nil }
}

typealias DefaultDistributedActorSystem = FakeActorSystem

// ==== Execute ----------------------------------------------------------------

func test_remote() async {
  let address = ActorAddress(parse: "sact://127.0.0.1/example#1234")
  var system: FakeActorSystem? = FakeActorSystem()

  let remote = try! SomeSpecificDistributedActor.resolve(id: address, using: system!)

  system = nil
  print("done") // CHECK: done

  print("remote.id = \(remote.id)") // CHECK: remote.id = ActorAddress(address: "sact://127.0.0.1/example#1234")
  print("remote.system = \(remote.actorSystem)") // CHECK: remote.system = main.FakeActorSystem

  // only once we exit the function and the remote is released, the system has no more references
  // CHECK-DAG: deinit ActorAddress(address: "sact://127.0.0.1/example#1234")
  // system must deinit after the last actor using it does deinit
  // CHECK-DAG: deinit main.FakeActorSystem
}

@main struct Main {
  static func main() async {
    await test_remote()
  }
}

