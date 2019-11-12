import Foundation

public enum ReaxError: Encodable {
  public func encode(to encoder: Encoder) throws {
    switch self {
    case .DeserializationError(let msg):
      try ["error": "DeserializationError", "message": msg].encode(to: encoder)
    case .SerializationError(let msg):
      try ["error": "SerializationError", "message": msg].encode(to: encoder)
    case .InternalServerError(let msg):
      try ["error": "InternalServerError", "message": msg].encode(to: encoder)
    case .ApplicationError(let msg):
      try ["error": "ApplicationError", "message": msg].encode(to: encoder)
    }}
  
  case DeserializationError(String)
  case SerializationError(String)
  case InternalServerError(String)
  case ApplicationError(String)
}

public enum ReaxContextState {
  case Started
  case Stopped
  case Error
}

public protocol ReaxContext {
  func state() -> ReaxContextState
}

public enum Either<A, B> {
  case Left(A)
  case Right(B)
}

public protocol ReaxMutation {
  associatedtype Context: ReaxContext
  associatedtype Result: Encodable
  
  func invoke(ctx: Context) -> Either<Result, ReaxError>
}

open class ReaxDecoder {
  let decoder = JSONDecoder()
  
  func decode<T>(_ type: T.Type, from data: Data) -> Either<T, ReaxError> where T : Decodable {
    if let result = try? self.decoder.decode(type, from: data) {
      return Either.Left(result)
    } else {
      let dataStr = String(data: data, encoding: .utf8) ?? "Unknown"
      let errStr = "Failed to decode: " + dataStr
      let err = ReaxError.DeserializationError(errStr)
      return Either.Right(err)
    }
  }
}

public protocol ReaxEventRouter {
  associatedtype Context: ReaxContext
  associatedtype Result: Encodable
  
  func routeEvent() -> ((_ ctx: Context, _ from: Data) -> Either<Result, ReaxError>)
}

public func mutationFactory<T>(_ type: T.Type) -> ((_ ctx: T.Context, _ from: Data) -> Either<T.Result, ReaxError>) where T: Codable & ReaxMutation {
  let decoder = ReaxDecoder()
  func decode (_ ctx: T.Context, _ from: Data) -> Either<T.Result, ReaxError> {
    switch decoder.decode(type, from: from) {
    case .Left(let result):
      return result.invoke(ctx: ctx)
    case .Right(let err):
      return Either.Right(err)
    }
  }
  return decode
}

// IMPL...
@objc
open class ReaxEventEmitter: RCTEventEmitter {
  let decoder = ReaxDecoder()
  let encoder = JSONEncoder()
  
  func errorType() -> String {
    let id = type(of: self)
    return "\(id)-error"
  }
  
  func resultType() -> String {
    let id = type(of: self)
    return "\(id)-result"
  }
  
  override open func constantsToExport() -> [AnyHashable : Any]! {
    return ["errorType": self.errorType(), "resultType": self.resultType()]
  }
  
  func dispatchError(error: ReaxError) {
    if let jsonData = try? encoder.encode(error) {
      let jsonString = String(data: jsonData, encoding: .utf8)
      self.sendEvent(withName: self.errorType(), body: jsonString)
    } else {
      self.sendEvent(withName: self.errorType(), body: "FAIL")
    }
  }
  
  func dispatchResult<T>(result: T) where T: Encodable {
    if let jsonData = try? encoder.encode(result) {
      let jsonString = String(data: jsonData, encoding: .utf8)
      self.sendEvent(withName: self.resultType(), body: jsonString)
    } else {
      let err = ReaxError.SerializationError("Failed to serailize result")
      self.dispatchError(error: err)
    }
  }
  
  public func channelFactory<T>(_ type: T.Type) -> ((_ result: Either<T, ReaxError>) -> Void) where T: Encodable {
    func channel (_ result: Either<T, ReaxError>) {
      switch result {
      case .Left(let result):
        self.dispatchResult(result: result)
      case .Right(let err):
        self.dispatchError(error: err)
      }
    }
    return channel
  }
  
  public func invoke<T>(_ type: T.Type, ctx: T.Context, id: String, args: String) where T: ReaxEventRouter & Decodable {
    if let eventData = id.data(using: .utf8) {
      switch decoder.decode(type, from: eventData) {
      case .Left(let router):
        let invokeMutation = router.routeEvent()
        if let argsData = args.data(using: .utf8) {
          switch invokeMutation(ctx, argsData) {
          case .Left(let result):
            self.dispatchResult(result: result)
          case .Right(let err):
            self.dispatchError(error: err)
          }
        } else {
          let err = ReaxError.DeserializationError("Failed to deserialize incoming args")
          self.dispatchError(error: err)
        }
      case .Right(let err):
        self.dispatchError(error: err)
      }
    } else {
      let err = ReaxError.DeserializationError("Failed to deserialize incoming event id")
      self.dispatchError(error: err)
    }
  }
}
