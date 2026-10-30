//
//  Origin.Step+Literal.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import WarpYAML

// A place's steps written by hand the way the spec writes them: a key as a
// string and a position in a list as an int.
extension Origin.Step: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .key(value)
    }
}

extension Origin.Step: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .index(value)
    }
}
