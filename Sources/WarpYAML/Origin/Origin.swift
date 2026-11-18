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
// what it was made from. A spelling the document gives a private procedure
// is read back as the one the text wrote.
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
        init(line: Int, column: Int) {
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

        // Which of the texts spent together the position is in, by its place
        // among them. Nil for a text spent alone, and where the walk reached
        // no node of one text.
        public let text: Int?

        // How many of the place's steps lead to the deepest node on the way
        // that the text wrote, and how many were asked for.
        public let followed: Int
        public let asked: Int

        // Whether the whole place was followed, so a caller knows whether it
        // points at the thing or at what encloses it.
        public var exact: Bool { followed == asked }

        // MARK: - Initializer
        init(position: Position, text: Int?, followed: Int, asked: Int) {
            self.position = position
            self.text = text
            self.followed = followed
            self.asked = asked
        }

        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The characters an identifier is written with, and the dot a full name
    // joins its identifiers with.
    private static let identifierCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
    private static let dot: Character = "."

    // The document's tree, as the bytes write it.
    let document: Tree

    // The spelling the text wrote, by the spelling the document gives each
    // private procedure it renames.
    private let spellings: [String: String]

    // MARK: - Initializer
    init(_ document: Tree, spellings: [String: String] = [:]) {
        self.document = document
        self.spellings = spellings
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
        var text = document.text
        var walked = 0
        var followed = 0

        for step in steps {
            guard let next = Self.child(of: reached, at: step) else { break }

            reached = next
            walked += 1

            if let started = next.position {
                position = started
                text = next.text
            }

            if !next.isImplicit {
                followed = walked
            }
        }

        return Reading(position: position, text: text, followed: followed, asked: steps.count)
    }

    // The place of what stands at a position of the text, the way back from
    // `reading(_:)`: the steps to the deepest node of the document standing
    // there, a node starting where it does standing until the next one
    // starts. A node the text wrote is taken over one a spend made from it.
    // No steps where nothing of the document stands at or before the
    // position. Of texts spent together, the position is in `text`, and the
    // nodes of every other text stand nowhere.
    public func place(at position: Position, inText text: Int? = nil) -> [Step] {
        document.path(to: position, inText: text).map(\.step)
    }

    // A message about the document, each spelling the document gives a
    // private procedure written as the text wrote it. A spelling is read
    // whole: one standing inside a longer name is that name's.
    public func demangled(_ message: String) -> String {
        guard !spellings.isEmpty else { return message }

        var demangled = ""
        var rest = Substring(message)

        while let character = rest.first {
            let follows = demangled.last.map { last in Self.identifierCharacters.contains(last) || last == Self.dot }
                ?? false
            let found = follows ? nil : spellings.first { given, _ in
                rest.hasPrefix(given) && !Self.continues(rest.dropFirst(given.count))
            }

            if let (given, spelling) = found {
                demangled += spelling
                rest = rest.dropFirst(given.count)
            } else {
                demangled.append(character)
                rest = rest.dropFirst()
            }
        }

        return demangled
    }

    // MARK: - Private
    // Whether what follows a spelling carries its name on: an identifier's
    // character, or a dot before one.
    private static func continues(_ rest: Substring) -> Bool {
        guard let next = rest.first else { return false }

        if identifierCharacters.contains(next) { return true }

        return next == dot && rest.dropFirst().first.map(identifierCharacters.contains) == true
    }

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
