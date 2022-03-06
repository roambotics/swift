//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Swift
import _Concurrency

@available(SwiftStdlib 5.7, *)
public protocol DistributedActorSystem: Sendable {
  /// The identity used by actors that communicate via this transport
  associatedtype ActorID: Sendable & Hashable & Codable // TODO: make Codable conditional here

  associatedtype InvocationEncoder: DistributedTargetInvocationEncoder
  associatedtype InvocationDecoder: DistributedTargetInvocationDecoder

  /// The serialization requirement that will be applied to all distributed targets used with this system.
  associatedtype SerializationRequirement
    where SerializationRequirement == InvocationEncoder.SerializationRequirement,
          SerializationRequirement == InvocationDecoder.SerializationRequirement

  // ==== ---------------------------------------------------------------------
  // - MARK: Resolving actors by identity
  /// Resolve a local or remote actor address to a real actor instance, or throw if unable to.
  /// The returned value is either a local actor or proxy to a remote actor.
  ///
  /// Resolving an actor is called when a specific distributed actors `init(from:)`
  /// decoding initializer is invoked. Once the actor's identity is deserialized
  /// using the `decodeIdentity(from:)` call, it is fed into this function, which
  /// is responsible for resolving the identity to a remote or local actor reference.
  ///
  /// If the resolve fails, meaning that it cannot locate a local actor managed for
  /// this identity, managed by this transport, nor can a remote actor reference
  /// be created for this identity on this transport, then this function must throw.
  ///
  /// If this function returns correctly, the returned actor reference is immediately
  /// usable. It may not necessarily imply the strict *existence* of a remote actor
  /// the identity was pointing towards, e.g. when a remote system allocates actors
  /// lazily as they are first time messaged to, however this should not be a concern
  /// of the sending side.
  ///
  /// Detecting liveness of such remote actors shall be offered / by transport libraries
  /// by other means, such as "watching an actor for termination" or similar.
  func resolve<Act>(id: ActorID, as actorType: Act.Type) throws -> Act?
    where Act: DistributedActor,
          Act.ID == ActorID

  // ==== ---------------------------------------------------------------------
  // - MARK: Actor Lifecycle
  /// Create an `ActorID` for the passed actor type.
  ///
  /// This function is invoked by an distributed actor during its initialization,
  /// and the returned address value is stored along with it for the time of its
  /// lifetime.
  ///
  /// The address MUST uniquely identify the actor, and allow resolving it.
  /// E.g. if an actor is created under address `addr1` then immediately invoking
  /// `system.resolve(id: addr1, as: Greeter.self)` MUST return a reference
  /// to the same actor.
  func assignID<Act>(_ actorType: Act.Type) -> ActorID
    where Act: DistributedActor,
          Act.ID == ActorID

  /// Invoked during a distributed actor's initialization, as soon as it becomes fully initialized.
  ///
  /// The system is expected to store the reference to this actor, and maintain an `ActorID: DistributedActor`
  /// mapping for the purpose of implementing the `resolve(id:as:)` method.
  ///
  /// The system usually should NOT retain the passed reference, and it will be informed via
  /// `resignID(_:)` when the actor has been deallocated so it can remove the stale reference from its
  /// internal `ActorID: DistributedActor` mapping.
  ///
  /// The `actor.id` of the passed actor must be an `ActorID` that this system previously has assigned.
  ///
  /// If the `actorReady` gets called with some unknown ID, it should crash immediately as it signifies some
  /// very unexpected use of the system.
  ///
  /// - Parameter actor: reference to the (local) actor that was just fully initialized.
  func actorReady<Act>(_ actor: Act)
    where Act: DistributedActor,
          Act.ID == ActorID

  /// Called during when a distributed actor is deinitialized, or fails to initialize completely (e.g. by throwing
  /// out of an `init` that did not completely initialize all of the the actors stored properties yet).
  ///
  /// This method is guaranteed to be called at-most-once for a given id (assuming IDs are unique,
  /// and not re-cycled by the system), i.e. if it is called during a failure to initialize completely,
  /// the call from the actor's deinitalizer will not happen (as under these circumstances, `deinit` will be run).
  ///
  /// If the `actorReady` gets called with some unknown ID, it should crash immediately as it signifies some
  /// very unexpected use of the system.
  ///
  /// - Parameter id: the id of an actor managed by this system that has begun its `deinit`.
  func resignID(_ id: ActorID)

  // ==== ---------------------------------------------------------------------
  // - MARK: Remote Method Invocations
  /// Invoked by the Swift runtime when a distributed remote call is about to be made.
  ///
  /// The returned `DistributedTargetInvocation` will be populated with all
  /// arguments, generic substitutions, and specific error and return types
  /// that are associated with this specific invocation.
  @inlinable
  func makeInvocationEncoder() -> InvocationEncoder

//  /// Invoked by the Swift runtime when making a remote call.
//  ///
//  /// The `arguments` are the arguments container that was previously created
//  /// by `makeInvocationEncoder` and has been populated with all arguments.
//  ///
//  /// This method should perform the actual remote function call, and await for its response.
//  ///
//  /// ## Errors
//  /// This method is allowed to throw because of underlying transport or serialization errors,
//  /// as well as by re-throwing the error received from the remote callee (if able to).
//  func remoteCall<Act, Err, Res>(
//      on actor: Act,
//      target: RemoteCallTarget,
//      invocation: inout InvocationEncoder,
//      throwing: Err.Type,
//      returning: Res.Type
//  ) async throws -> Res
//      where Act: DistributedActor,
//            Act.ID == ActorID,
//            Err: Error,
//            Res: SerializationRequirement

//  /// Invoked by the Swift runtime when making a remote call.
//  ///
//  /// The `arguments` are the arguments container that was previously created
//  /// by `makeInvocationEncoder` and has been populated with all arguments.
//  ///
//  /// This method should perform the actual remote function call, and await for its response.
//  ///
//  /// ## Errors
//  /// This method is allowed to throw because of underlying transport or serialization errors,
//  /// as well as by re-throwing the error received from the remote callee (if able to).
//  func remoteCallVoid<Act, Err>(
//      on actor: Act,
//      target: RemoteCallTarget,
//      invocation: inout InvocationEncoder,
//      throwing: Err.Type
//  ) async throws -> Res
//      where Act: DistributedActor,
//            Act.ID == ActorID,
//            Err: Error

}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Execute Distributed Methods
@available(SwiftStdlib 5.7, *)
extension DistributedActorSystem {

  /// Prepare and execute a call to the distributed function identified by the passed arguments,
  /// on the passed `actor`, and collect its results using the `ResultHandler`.
  ///
  /// This method encapsulates multiple steps that are invoked in executing a distributed function,
  /// into one very efficient implementation. The steps involved are:
  ///
  /// - looking up the distributed function based on its name
  /// - decoding, in an efficient manner, all arguments from the `Args` container into a well-typed representation
  /// - using that representation to perform the call on the target method
  ///
  /// The reason for this API using a `ResultHandler` rather than returning values directly,
  /// is that thanks to this approach it can avoid any existential boxing, and can serve the most
  /// latency sensitive-use-cases.
  public func executeDistributedTarget<Act, ResultHandler>(
    on actor: Act,
    mangledTargetName: String,
    invocationDecoder: inout InvocationDecoder,
    handler: ResultHandler
  ) async throws where Act: DistributedActor,
                       // Act.ID == ActorID, // FIXME(distributed): can we bring this back?
                       ResultHandler: DistributedTargetInvocationResultHandler {
    // NOTE: this implementation is not the most efficient, nor final, version of this func
    // we end up demangling the name multiple times, perform more heap allocations than
    // we truly need to etc. We'll eventually move this implementation to a specialized one
    // avoiding these issues.
    guard mangledTargetName.count > 0 && mangledTargetName.first == "$" else {
      throw ExecuteDistributedTargetError(
        message: "Illegal mangledTargetName detected, must start with '$'")
    }

    // Get the expected parameter count of the func
    let nameUTF8 = Array(mangledTargetName.utf8)

    // Gen the generic environment (if any) associated with the target.
    let genericEnv = nameUTF8.withUnsafeBufferPointer { nameUTF8 in
      _getGenericEnvironmentOfDistributedTarget(nameUTF8.baseAddress!,
                                                UInt(nameUTF8.endIndex))
    }

    var substitutionsBuffer: UnsafeMutablePointer<Any.Type>? = nil
    var witnessTablesBuffer: UnsafeRawPointer? = nil
    var numWitnessTables: Int = 0

    defer {
      substitutionsBuffer?.deallocate()
      witnessTablesBuffer?.deallocate()
    }

    if let genericEnv = genericEnv {
      let subs = try invocationDecoder.decodeGenericSubstitutions()

      if subs.isEmpty {
        throw ExecuteDistributedTargetError(
          message: "Cannot call generic method without generic argument substitutions")
      }

      substitutionsBuffer = .allocate(capacity: subs.count)

      for (offset, substitution) in subs.enumerated() {
        let element = substitutionsBuffer?.advanced(by: offset)
        element?.initialize(to: substitution)
      }

      (witnessTablesBuffer, numWitnessTables) = _getWitnessTablesFor(environment: genericEnv,
                                                                     genericArguments: substitutionsBuffer!)
      if numWitnessTables < 0 {
        throw ExecuteDistributedTargetError(
          message: "Generic substitutions \(subs) do not satisfy generic requirements of \(mangledTargetName)")
      }
    }

    let paramCount = nameUTF8.withUnsafeBufferPointer { nameUTF8 in
      __getParameterCount(nameUTF8.baseAddress!, UInt(nameUTF8.endIndex))
    }

    guard paramCount >= 0 else {
      throw ExecuteDistributedTargetError(
        message: """
                 Failed to decode distributed invocation target expected parameter count,
                 error code: \(paramCount)
                 mangled name: \(mangledTargetName)
                 """)
    }

    // Prepare buffer for the parameter types to be decoded into:
    let argumentTypesBuffer = UnsafeMutableBufferPointer<Any.Type>.allocate(capacity: Int(paramCount))
    defer {
      argumentTypesBuffer.deallocate()
    }

    // Demangle and write all parameter types into the prepared buffer
    let decodedNum = nameUTF8.withUnsafeBufferPointer { nameUTF8 in
      __getParameterTypeInfo(
        nameUTF8.baseAddress!, UInt(nameUTF8.endIndex),
        genericEnv,
        substitutionsBuffer,
        argumentTypesBuffer.baseAddress!._rawValue, Int(paramCount))
    }

    // Fail if the decoded parameter types count seems off and fishy
    guard decodedNum == paramCount else {
      throw ExecuteDistributedTargetError(
        message: """
                 Failed to decode the expected number of params of distributed invocation target, error code: \(decodedNum)
                 (decoded: \(decodedNum), expected params: \(paramCount)
                 mangled name: \(mangledTargetName)
                 """)
    }

    // Copy the types from the buffer into a Swift Array
    var argumentTypes: [Any.Type] = []
    do {
      argumentTypes.reserveCapacity(Int(decodedNum))
      for argumentType in argumentTypesBuffer {
        argumentTypes.append(argumentType)
      }
    }

    // Decode the return type
    func allocateReturnTypeBuffer<R>(_: R.Type) -> UnsafeRawPointer? {
      return UnsafeRawPointer(UnsafeMutablePointer<R>.allocate(capacity: 1))
    }

    guard let returnTypeFromTypeInfo: Any.Type = _getReturnTypeInfo(mangledMethodName: mangledTargetName,
                                                                    genericEnv: genericEnv,
                                                                    genericArguments: substitutionsBuffer) else {
      throw ExecuteDistributedTargetError(
        message: "Failed to decode distributed target return type")
    }

    guard let resultBuffer = _openExistential(returnTypeFromTypeInfo, do: allocateReturnTypeBuffer) else {
      throw ExecuteDistributedTargetError(
        message: "Failed to allocate buffer for distributed target return type")
    }

    func destroyReturnTypeBuffer<R>(_: R.Type) {
      resultBuffer.assumingMemoryBound(to: R.self).deallocate()
    }

    defer {
      _openExistential(returnTypeFromTypeInfo, do: destroyReturnTypeBuffer)
    }

    do {
      let returnType = try invocationDecoder.decodeReturnType() ?? returnTypeFromTypeInfo
      // let errorType = try invocation.decodeErrorType() // TODO(distributed): decide how to use?

      // Execute the target!
      try await _executeDistributedTarget(
        on: actor,
        mangledTargetName, UInt(mangledTargetName.count),
        argumentDecoder: &invocationDecoder,
        argumentTypes: argumentTypesBuffer.baseAddress!._rawValue,
        resultBuffer: resultBuffer._rawValue,
        substitutions: UnsafeRawPointer(substitutionsBuffer),
        witnessTables: witnessTablesBuffer,
        numWitnessTables: UInt(numWitnessTables)
      )

      func onReturn<R>(_ resultTy: R.Type) async throws {
        try await handler.onReturn/*<R>*/(value: resultBuffer.load(as: resultTy))
      }
      try await _openExistential(returnType, do: onReturn)
    } catch {
      try await handler.onThrow(error: error)
    }
  }
}

@available(SwiftStdlib 5.7, *)
@_silgen_name("swift_distributed_execute_target")
func _executeDistributedTarget<D: DistributedTargetInvocationDecoder>(
  on actor: AnyObject, // DistributedActor
  _ targetName: UnsafePointer<UInt8>, _ targetNameLength: UInt,
  argumentDecoder: inout D,
  argumentTypes: Builtin.RawPointer,
  resultBuffer: Builtin.RawPointer,
  substitutions: UnsafeRawPointer?,
  witnessTables: UnsafeRawPointer?,
  numWitnessTables: UInt
) async throws

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Support types
/// A distributed 'target' can be a `distributed func` or `distributed` computed property.
@available(SwiftStdlib 5.7, *)
public struct RemoteCallTarget {
  let _mangledName: String // TODO: StaticString would be better here; no arc, codesize of cleanups

  // Only intended to be created by the _Distributed library.
  // TODO(distributed): make this internal and only allow calling by the synthesized code?
  public init(_mangledName: String) {
    self._mangledName = _mangledName
  }

  public var mangledName: String {
    _mangledName
  }

  // <module>.Base.hello(hi:)
  public var fullName: String {
    fatalError("NOT IMPLEMENTED YET: \(#function)")
  }
}

/// Used to encode an invocation of a distributed target (method or computed property).
///
/// ## Forming an invocation
///
/// On the sending-side an instance of an invocation is constructed by the runtime,
/// and calls to: `recordGenericSubstitution`, `recordArgument`, `recordReturnType`,
/// `recordErrorType`, and finally `doneRecording` are made (in this order).
///
/// If the return type of the target is `Void` the `recordReturnType` is not invoked.
///
/// If the error type thrown by the target is not defined the `recordErrorType` is not invoked.
///
/// An invocation implementation may decide to perform serialization right-away in the
/// `record...` invocations, or it may choose to delay doing so until the invocation is passed
/// to the `remoteCall`. This decision largely depends on if serialization is allowed to happen
/// on the caller's task, and if any smarter encoding can be used once all parameter calls have been
/// recorded (e.g. it may be possible to run-length encode values of certain types etc.)
///
/// Once encoded, the system should use some underlying transport mechanism to send the
/// bytes serialized by the invocation to the remote peer.
///
/// ## Decoding an invocation
/// Since every actor system is going to deal with a concrete invocation type, they may
/// implement decoding them whichever way is most optimal for the given system.
///
/// Once decided, the invocation must be passed to `executeDistributedTarget`
/// which will decode the substitutions, argument values, return and error types (in that order).
///
/// Note that the decoding will be provided the specific types that the sending side used to preform the call,
/// so decoding can rely on simply invoking e.g. `Codable` (if that is the `SerializationRequirement`) decoding
/// entry points on the provided types.
public protocol DistributedTargetInvocationEncoder {
  associatedtype SerializationRequirement

  /// The arguments must be encoded order-preserving, and once `decodeGenericSubstitutions`
  /// is called, the substitutions must be returned in the same order in which they were recorded.
  mutating func recordGenericSubstitution<T>(_ type: T.Type) throws

//  /// Ad-hoc requirement
//  ///
//  /// Record an argument of `Argument` type.
//  /// This will be invoked for every argument of the target, in declaration order.
//  mutating func recordArgument<Argument: SerializationRequirement>(_ argument: Argument) throws
  // TODO(distributed): offer recordArgument(label:type:)

//  /// Ad-hoc requirement
//  ///
//  /// Record the error type of the distributed method.
//  /// This method will not be invoked if the target is not throwing.
//  mutating func recordErrorType<E: Error>(_ type: E.Type) throws

//  /// Ad-hoc requirement
//  ///
//  /// Record the return type of the distributed method.
//  /// This method will not be invoked if the target is returning `Void`.
//  mutating func recordReturnType<R: SerializationRequirement>(_ type: R.Type) throws

  mutating func doneRecording() throws
}

/// Decoder that must be provided to `executeDistributedTarget` and is used
/// by the Swift runtime to decode arguments of the invocation.
public protocol DistributedTargetInvocationDecoder {
  associatedtype SerializationRequirement

  mutating func decodeGenericSubstitutions() throws -> [Any.Type]

//  /// Ad-hoc protocol requirement
//  ///
//  /// Attempt to decode the next argument from the underlying buffers into pre-allocated storage
//  /// pointed at by 'pointer'.
//  ///
//  /// This method should throw if it has no more arguments available, if decoding the argument failed,
//  /// or, optionally, if the argument type we're trying to decode does not match the stored type.
//  ///
//  /// The result of the decoding operation must be stored into the provided 'pointer' rather than
//  /// returning a value. This pattern allows the runtime to use a heavily optimized, pre-allocated
//  /// buffer for all the arguments and their expected types. The 'pointer' passed here is a pointer
//  /// to a "slot" in that pre-allocated buffer. That buffer will then be passed to a thunk that
//  /// performs the actual distributed (local) instance method invocation.
//  mutating func decodeNextArgument<Argument: SerializationRequirement>() throws -> Argument

  mutating func decodeErrorType() throws -> Any.Type?

  mutating func decodeReturnType() throws -> Any.Type?
}

@available(SwiftStdlib 5.7, *)
public protocol DistributedTargetInvocationResultHandler {
  associatedtype SerializationRequirement

  // FIXME(distributed): these must be ad-hoc protocol requirements, because Res: SerializationRequirement !!!
  func onReturn<Res>(value: Res) async throws
  func onReturnVoid() async throws

  func onThrow<Err: Error>(error: Err) async throws
}

/******************************************************************************/
/******************************** Errors **************************************/
/******************************************************************************/

/// Error protocol to which errors thrown by any `DistributedActorSystem` should conform.
@available(SwiftStdlib 5.7, *)
public protocol DistributedActorSystemError: Error {}

@available(SwiftStdlib 5.7, *)
public struct ExecuteDistributedTargetError: DistributedActorSystemError {
  let message: String

  public init(message: String) {
    self.message = message
  }
}

@available(SwiftStdlib 5.7, *)
public struct DistributedActorCodingError: DistributedActorSystemError {
  public let message: String

  public init(message: String) {
    self.message = message
  }

  public static func missingActorSystemUserInfo<Act>(_ actorType: Act.Type) -> Self
      where Act: DistributedActor {
    .init(message: "Missing DistributedActorSystem userInfo while decoding")
  }
}
