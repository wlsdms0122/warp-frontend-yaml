//
//  Shadowing.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a declaration of a name in a space shadows for a text that leans on
// it: the declarations the name stands for there, and whether the notation
// reads the name as a key of its own.
public struct Shadowing: Sendable, Equatable {
    // MARK: - Property
    // The full names of the declarations the name stands for, in order.
    public let declarations: [Name]

    // A one-key mapping under the name is read as the notation's own, a form,
    // a template, an operator or a construct, and not as a call to the
    // declaration.
    public let isKeyword: Bool

    // MARK: - Initializer
    init(declarations: [Name], isKeyword: Bool) {
        self.declarations = declarations
        self.isKeyword = isKeyword
    }

    // MARK: - Public
    // MARK: - Private
}
