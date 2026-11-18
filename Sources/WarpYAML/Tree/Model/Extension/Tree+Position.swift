//
//  Tree+Position.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// The way down a tree to what stands at a position of the text. A node holds
// where it starts and nothing of where it ends, so what stands at a
// position is the child starting last at or before it, at every depth. In a
// document spent from several texts, a node holding what more than one text
// wrote starts, in each text, where the first of that text's nodes in it
// does.
extension Tree {
    // MARK: - Public
    // Each step down to the deepest node standing at `position`, with the
    // node it reaches. Of children starting at one position, the one the
    // text wrote is taken over one a spend made. Empty where no child starts
    // at or before the position.
    func path(to position: Origin.Position, inText text: Int? = nil) -> [(step: Origin.Step, node: Tree)] {
        var path: [(step: Origin.Step, node: Tree)] = []
        var node = self

        while let next = Self.child(of: node, at: position, inText: text) {
            path.append(next)
            node = next.node
        }

        return path
    }

    // MARK: - Private
    private static func child(
        of node: Tree,
        at position: Origin.Position,
        inText text: Int?
    ) -> (step: Origin.Step, node: Tree)? {
        let children: [(step: Origin.Step, node: Tree)] = switch node.content {
        case let .array(elements):
            elements.enumerated().map { index, element in (.index(index), element) }

        case let .dictionary(entries):
            entries.sorted { first, second in first.key < second.key }.map { key, value in (.key(key), value) }

        case .null, .bool, .int, .double, .string:
            []
        }

        return children
            .compactMap { child in child.node.start(inText: text).map { start in (child, start) } }
            .filter { _, start in !Self.precedes(position, start) }
            .max { first, second in
                guard first.1 != second.1 else { return first.0.node.isImplicit && !second.0.node.isImplicit }

                return precedes(first.1, second.1)
            }
            .map { child, _ in child }
    }

    // Where the node starts in a text: its own position where it stands in
    // that text, and otherwise where the first node of that text it holds
    // does.
    private func start(inText text: Int?) -> Origin.Position? {
        guard self.text != text else { return position }

        let held: [Tree] = switch content {
        case let .array(elements): elements
        case let .dictionary(entries): Array(entries.values)
        case .null, .bool, .int, .double, .string: []
        }

        return held.compactMap { node in node.start(inText: text) }.min(by: Self.precedes)
    }

    private static func precedes(_ first: Origin.Position, _ second: Origin.Position) -> Bool {
        (first.line, first.column) < (second.line, second.column)
    }
}
