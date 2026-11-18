//
//  Tree+Hashable.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// Two trees are equal by what they hold, wherever they came from, so a spent
// tree compares with one written by hand.
extension Tree: Hashable {
    // MARK: - Public
    static func == (lhs: Tree, rhs: Tree) -> Bool {
        lhs.content == rhs.content
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(content)
    }
}
