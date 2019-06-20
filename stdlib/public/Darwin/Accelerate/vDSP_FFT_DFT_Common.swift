//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension vDSP {
    @available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *)
    public enum FourierTransformDirection {
        case forward
        case inverse
        
        public var dftDirection: vDSP_DFT_Direction {
            switch self {
            case .forward:
                return .FORWARD
            case .inverse:
                return .INVERSE
            }
        }
        
        public var fftDirection: FFTDirection {
            switch self {
            case .forward:
                return FFTDirection(kFFTDirection_Forward)
            case .inverse:
                return FFTDirection(kFFTDirection_Inverse)
            }
        }
    }
}
