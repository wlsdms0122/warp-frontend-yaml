//
//  Tree+Literal.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
@testable import WarpYAML

// A tree written by hand the way the spec's pages write part of one.
extension Tree: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension Tree: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension Tree: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension Tree: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension Tree: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Tree: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Tree...) {
        self = .array(elements)
    }
}

extension Tree: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Tree)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}
