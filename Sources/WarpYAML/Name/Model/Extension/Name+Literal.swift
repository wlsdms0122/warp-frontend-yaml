//
//  Name+Literal.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A name written in Swift. The spelling is source an author typed, so a
// spelling that is not a name is a mistake made where it can be read, and
// there is nothing to return. A spelling from anywhere else goes through
// the throwing initializer.
extension Name: ExpressibleByStringLiteral {
    public init(stringLiteral spelling: String) {
        do {
            try self.init(spelling)
        } catch {
            preconditionFailure("'\(spelling)' cannot be a name: \(error)")
        }
    }
}
