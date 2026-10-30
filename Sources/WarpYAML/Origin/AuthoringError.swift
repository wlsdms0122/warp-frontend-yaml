//
//  AuthoringError.swift
//  WarpYAML
//
//  Created by JSilver on 8/31/26.
//

import Foundation

// What the Front refuses a text with: the sentence, where in the text it
// stands, and, among texts handed together, which text.
public struct AuthoringError: Error, Sendable, Equatable, CustomStringConvertible {
    // MARK: - Property
    public let message: String

    // Where in the text handed the refusal stands: a YAML text, or a
    // declaration file. Nil where the refusal is of no one spot of it.
    public let position: Origin.Position?

    // Which of the texts handed together the refusal stands in, by its
    // position among them, and nil for a text handed alone.
    public let text: Int?

    public var description: String {
        let among = text.map { text in "text \(text), " } ?? ""

        return position.map { position in "\(among)\(position): \(message)" } ?? "\(among)\(message)"
    }

    // MARK: - Initializer
    init(_ message: String, at position: Origin.Position? = nil) {
        self.init(message, at: position, inText: nil)
    }

    // The Front's refusal of what a text writes, at the node it refuses.
    init(_ message: String, at node: Tree) {
        self.init(message, at: node.position)
    }

    // A refusal made where no node is held, at the node it is about. One
    // already placed keeps its position.
    init(_ refusal: AuthoringError, at node: Tree) {
        self.init(refusal.message, at: refusal.position ?? node.position, inText: refusal.text)
    }

    // The refusal of a mapping's keys a shorthand does not write, at the
    // first of them by name, and nothing where it writes every key.
    init?(keysOf node: Tree, outside known: Set<String>, in context: String) {
        guard let entries = node.dictionaryValue else { return nil }

        let unknown = entries.keys.filter { key in !known.contains(key) }.sorted()

        guard let first = unknown.first, let written = entries[first] else { return nil }

        self.init(
            "\(context): unknown key(s) \(unknown.joined(separator: ", ")). Known keys: \(known.sorted().joined(separator: ", "))",
            at: written
        )
    }

    // The refusal of one text among several, in that text.
    init(_ refusal: AuthoringError, inText text: Int) {
        self.init(refusal.message, at: refusal.position, inText: text)
    }

    private init(_ message: String, at position: Origin.Position?, inText text: Int?) {
        self.message = message
        self.position = position
        self.text = text
    }

    // MARK: - Public
    // MARK: - Private
}
