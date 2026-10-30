//
//  Tree.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A value tree as the document format lays a document out: what an encoding
// carries, with a dictionary keyed by the strings a document writes. Each
// node carries the YAML position it came from, and whether a pass made it
// from what the text wrote at that position (an implicit node) rather than
// the text writing it. Equality and hashing read the content only.
struct Tree: Sendable {
    enum Content: Sendable, Hashable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([Tree])
        case dictionary([String: Tree])
    }

    // MARK: - Property
    let content: Content
    // The position in the YAML text, and nothing for a tree no YAML text
    // wrote (a declaration file, a tree written by hand).
    let position: Origin.Position?
    let isImplicit: Bool

    var boolValue: Bool? {
        guard case let .bool(value) = content else { return nil }

        return value
    }

    var stringValue: String? {
        guard case let .string(value) = content else { return nil }

        return value
    }

    var arrayValue: [Tree]? {
        guard case let .array(elements) = content else { return nil }

        return elements
    }

    var dictionaryValue: [String: Tree]? {
        guard case let .dictionary(entries) = content else { return nil }

        return entries
    }

    // MARK: - Initializer
    init(
        _ content: Content,
        at position: Origin.Position? = nil,
        isImplicit: Bool = false
    ) {
        self.content = content
        self.position = position
        self.isImplicit = isImplicit
    }

    // MARK: - Public
    static let null = Tree(Content.null)

    static func bool(_ value: Bool) -> Tree {
        Tree(Content.bool(value))
    }

    static func int(_ value: Int) -> Tree {
        Tree(Content.int(value))
    }

    static func double(_ value: Double) -> Tree {
        Tree(Content.double(value))
    }

    static func string(_ value: String) -> Tree {
        Tree(Content.string(value))
    }

    static func array(_ elements: [Tree]) -> Tree {
        Tree(Content.array(elements))
    }

    static func dictionary(_ entries: [String: Tree]) -> Tree {
        Tree(Content.dictionary(entries))
    }

    // What a dictionary holds under a key, and nothing for a key it does not
    // hold or a tree that is no dictionary.
    subscript(key: String) -> Tree? {
        dictionaryValue?[key]
    }

    // The same content at another position, as the text wrote it.
    func positioned(at position: Origin.Position?) -> Tree {
        Tree(content, at: position, isImplicit: isImplicit)
    }

    // The same node holding other content, where a walk rewrote what it
    // holds.
    func holding(_ content: Content) -> Tree {
        Tree(content, at: position, isImplicit: isImplicit)
    }

    // A tree a pass makes from this node. Each node of it no text wrote
    // stands at this node's position, implicit; a node the text wrote,
    // carried into it, keeps its own.
    func making(_ tree: Tree) -> Tree {
        guard tree.position == nil else { return tree }

        let content: Content = switch tree.content {
        case let .array(elements):
            .array(elements.map(making))

        case let .dictionary(entries):
            .dictionary(entries.mapValues(making))

        case .null, .bool, .int, .double, .string:
            tree.content
        }

        return Tree(content, at: position, isImplicit: true)
    }

    // MARK: - Private
}
