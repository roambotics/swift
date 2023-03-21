// RUN: %target-run-simple-swift(-Xfrontend -sil-verify-all) | %FileCheck %s --implicit-check-not closing

// REQUIRES: executable_test

// NOTE: it's important that this test has the `--implicit-check-not closing` flag to catch double deinits!!
// you also want to make sure all messages start with "closing"
func posix_close(_ x: Int) { print("closing file descriptor: \(x)") }
func print_closing_MFD() { print("closing MaybeFileDescriptor") }

enum E: Error { case err }

@_moveOnly
struct FileDescriptor {
  var fd: Int
  static var nextFD: Int = 0

  init() {
    self.fd = FileDescriptor.nextFD
    FileDescriptor.nextFD += 1
  }

  init(doForget: Bool) throws {
    self.init()
    if doForget {
      _forget self
      throw E.err
    }
  }

  __consuming func close() {
    posix_close(fd)
    _forget self
  }

  __consuming func justForget() {
    _forget self
  }

  __consuming func empty() {}

  var takeFileDescriptorWrong : Int {
    __consuming get {
      return fd
    }
  }

  var takeFileDescriptorRight : Int {
    __consuming get {
      let x = fd
      _forget self
      return x
    }
  }

  deinit {
    posix_close(fd)
  }
}

@_moveOnly enum MaybeFileDescriptor {
  case some(FileDescriptor)
  case nothing

  init(reinit: Bool) {
    self = .some(FileDescriptor())
    if reinit {
      _forget self
      self = .some(FileDescriptor())
    }
  }

  __consuming func skipDeinit() {
    _forget self
  }

  deinit {
    // we can't do a borrowed switch yet so this is just printing some message
    print_closing_MFD()
  }
}

func main() {
  let _ = {
    let x = FileDescriptor() // 0
    x.close()
    // CHECK: closing file descriptor: 0
  }()

  let _ = {
    let _ = FileDescriptor() // 1
    // CHECK: closing file descriptor: 1
  }()

  let _ = {
    let x = FileDescriptor() // 2
    x.justForget()
  }()

  let _ = {
    let x = FileDescriptor() // 3
    x.empty()
    // CHECK: closing file descriptor: 3
  }()

  let _ = {
    let x = FileDescriptor() // 4
    _ = x.takeFileDescriptorWrong
    // CHECK: closing file descriptor: 4
  }()

  let _ = {
    let x = FileDescriptor() // 5
    _ = x.takeFileDescriptorRight
  }()

  let _ = {
    do {
      // should throw before getting to close()
      let x = try FileDescriptor(doForget: true) // 6
      x.close()
    } catch {}
  }()

  let _ = {
    do {
      let x = try FileDescriptor(doForget: false) // 7
      x.close()
    } catch {}
    // CHECK: closing file descriptor: 7
  }()

  let _ = {
    let _ = MaybeFileDescriptor(reinit: true) // 8 & 9
    // CHECK: closing file descriptor: 8
    // CHECK: closing MaybeFileDescriptor
    // CHECK: closing file descriptor: 9
  }()

  let _ = {
    let x = MaybeFileDescriptor(reinit: true) // 10 & 11
    x.skipDeinit() // this skips the enum's deinit, not the file descriptor's!
    // CHECK: closing file descriptor: 10
    // CHECK: closing file descriptor: 11
  }()

  let _ = {
    var maybe = MaybeFileDescriptor.nothing
    maybe = .some(FileDescriptor()) // 12
    // CHECK: closing MaybeFileDescriptor
    // CHECK: closing MaybeFileDescriptor
    // CHECK: closing file descriptor: 12
  }()

  let _ = {
    let x = MaybeFileDescriptor(reinit: false) // 13
    x.skipDeinit() // this skips the enum's deinit, not the file descriptor's!
    // CHECK: closing file descriptor: 13
  }()

}

main()
