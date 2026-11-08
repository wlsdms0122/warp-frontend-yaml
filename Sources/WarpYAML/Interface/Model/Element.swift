//
//  Element.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What the text's first layer reads: an atom, or a list of elements, each
// where it begins in the text.
indirect enum Element: Sendable, Hashable {
    case atom(Atom, at: Origin.Position)
    case list([Element], at: Origin.Position)

    // MARK: - Property
    var position: Origin.Position {
        switch self {
        case let .atom(_, position), let .list(_, position):
            position
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
