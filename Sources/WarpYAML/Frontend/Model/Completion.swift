//
//  Completion.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// What a completion at a position of a text reads. What stands there is
// written as what it reads, so the text spends while it is being written:
// its document and their `Origin`, the value names readable there, and,
// where the position stands in a path after a dot, the place of the path
// before the dot, whose type whoever builds the document judges.
public struct Completion: Sendable {
    // MARK: - Property
    public let document: Data
    public let origin: Origin

    // The value names readable at the position, each once, in the order of
    // their spelling.
    public let names: [Name]

    // The place of the path written before the dot, and nil where the
    // position stands after none.
    public let receiver: [Origin.Step]?

    // MARK: - Initializer
    init(document: Data, origin: Origin, names: [Name], receiver: [Origin.Step]?) {
        self.document = document
        self.origin = origin
        self.names = names
        self.receiver = receiver
    }

    // MARK: - Public
    // MARK: - Private
}
