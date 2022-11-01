import _CompilerPluginSupport

struct StringifyMacro: _CompilerPlugin {
  static func _name() -> (UnsafePointer<UInt8>, count: Int) {
    var name = "customStringify"
    return name.withUTF8 { buffer in
      let result = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.count)
      result.initialize(from: buffer.baseAddress!, count: buffer.count)
      return (UnsafePointer(result), count: buffer.count)
    }
  }

  static func _kind() -> _CompilerPluginKind {
    .expressionMacro
  }

  static func _rewrite(
    targetModuleName: UnsafePointer<UInt8>,
    targetModuleNameCount: Int,
    filePath: UnsafePointer<UInt8>,
    filePathCount: Int,
    sourceFileText: UnsafePointer<UInt8>,
    sourceFileTextCount: Int,
    localSourceText: UnsafePointer<UInt8>,
    localSourceTextCount: Int
  ) -> (UnsafePointer<UInt8>?, count: Int) {
    let meeTextBuffer = UnsafeBufferPointer(
      start: localSourceText, count: localSourceTextCount)
    let meeText = String(decoding: meeTextBuffer, as: UTF8.self)
    let prefix = "#customStringify("
    guard meeText.starts(with: prefix), meeText.last == ")" else {
      return (nil, 0)
    }
    let expr = meeText.dropFirst(prefix.count).dropLast()
    // Or use regex...
    //   let match = meeText.firstMatch {
    //     "#customStringify"
    //     ZeroOrMore {
    //       CharacterClass(.whitespace, .newlineSequence)
    //     }
    //     "("
    //     Capture(OneOrMore(.any))
    //     ")"
    //     ZeroOrMore {
    //       CharacterClass(.whitespace, .newlineSequence)
    //     }
    //   }
    //   guard let expr = match?.1 else {
    //     return (nil, count: 0)
    //   }

    var resultString = "(\(expr), #\"\(expr)\"#)"
    return resultString.withUTF8 { buffer in
      let result = UnsafeMutableBufferPointer<UInt8>.allocate(
          capacity: buffer.count + 1)
      _ = result.initialize(from: buffer)
      result[buffer.count] = 0
      return (UnsafePointer(result.baseAddress), buffer.count)
    }
  }
}

public var allMacros: [Any.Type] {
  [StringifyMacro.self]
}
