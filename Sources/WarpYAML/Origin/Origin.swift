//
//  Origin.swift
//  WarpYAML
//
//  Created by JSilver on 8/30/26.
//

import Foundation

// Where the text is, for a place in the document a text was spent into. A
// place names a spot by the steps from the document's root to it, each a key
// the document writes or a position in a list the document writes, and this
// walks those steps in the document's tree. Each node of that tree stands
// where the text wrote it, or, for a node a spend made, where the text wrote
// what it was made from.
public struct Origin: Sendable {
    // One step of a place: a key the document writes, or a position in a
    // list it writes, counted from zero.
    public enum Step: Sendable, Hashable {
        case key(String)
        case index(Int)
    }

    public struct Position: Sendable, Hashable, CustomStringConvertible {
        // MARK: - Property
        // Line and column, both from one. The column counts unicode scalars,
        // so on a line holding a combining mark it is not an editor's caret.
        public let line: Int
        public let column: Int

        public var description: String { "\(line):\(column)" }

        // MARK: - Initializer
        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }

        // MARK: - Public
        // MARK: - Private
    }

    // How far a place got, together with where it stopped.
    public struct Reading: Sendable, Equatable {
        // MARK: - Property
        public let position: Position

        // How many of the place's steps lead to the deepest node on the way
        // that the text wrote, and how many were asked for.
        public let followed: Int
        public let asked: Int

        // Whether the whole place was followed, so a caller knows whether it
        // points at the thing or at what encloses it.
        public var exact: Bool { followed == asked }

        // MARK: - Initializer
        init(position: Position, followed: Int, asked: Int) {
            self.position = position
            self.followed = followed
            self.asked = asked
        }

        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The document's tree, as the bytes write it.
    let document: Tree

    // MARK: - Initializer
    init(_ document: Tree) {
        self.document = document
    }

    // MARK: - Public
    // Following a place's steps into the document, as far as the document
    // goes. The reading stands at the node the walk reached, and follows the
    // steps as far as the deepest node on the way that the text wrote, so a
    // node a spend made, or a step the document does not have, is not exact.
    public func reading(_ steps: [Step]) -> Reading {
        var reached = document
        // The text's start stands for a root no text wrote.
        var position = document.position ?? Position(line: 1, column: 1)
        var walked = 0
        var followed = 0

        for step in steps {
            guard let next = Self.child(of: reached, at: step) else { break }

            reached = next
            position = next.position ?? position
            walked += 1

            if !next.isImplicit {
                followed = walked
            }
        }

        return Reading(position: position, followed: followed, asked: steps.count)
    }

    // MARK: - Private
    private static func child(of node: Tree, at step: Step) -> Tree? {
        switch (step, node.content) {
        case let (.key(key), .dictionary(entries)):
            entries[key]

        case let (.index(index), .array(elements)) where elements.indices.contains(index):
            elements[index]

        default:
            nil
        }
    }
}
