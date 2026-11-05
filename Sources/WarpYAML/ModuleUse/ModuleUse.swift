//
//  ModuleUse.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// The modules a text uses, which it writes under `uses:` by name, each an
// identifier: `uses: [ Lib, Host ]`. The text reads the declarations of
// those modules beside its own module's and `Standard`'s, which every text
// uses whether or not it names it. The document has no such key, so it is
// spent here. What the document imports is the front end's to write, so a
// text writing `imports:` or `importedClaims:` is refused where it writes it.
struct ModuleUse {
    // MARK: - Property
    static let key = "uses"

    // The modules the text names, each at where it is written.
    let modules: [(name: Name, at: Tree)]

    // The text with the key spent.
    let text: Tree

    // MARK: - Initializer
    // A parsed text. `uses:` that is no list of identifiers is refused
    // where it is written.
    init(of text: Tree) throws(AuthoringError) {
        if let key = OneWay.writtenKeys.first(where: { key in text[key] != nil }), let written = text[key] {
            throw AuthoringError(
                "a text writes the modules it uses under 'uses', and the front end writes '\(key)'",
                at: written
            )
        }

        guard var entries = text.dictionaryValue, let written = entries[Self.key] else {
            self.modules = []
            self.text = text

            return
        }

        guard let listed = written.arrayValue else {
            throw AuthoringError("'uses' is a list of the modules the text uses", at: written)
        }

        self.modules = try listed.map { element throws(AuthoringError) in
            guard let spelling = element.stringValue, let name = try? Name(spelling), name.isIdentifier else {
                throw AuthoringError("a module is named by an identifier", at: element)
            }

            return (name, element)
        }

        entries[Self.key] = nil

        self.text = text.holding(.dictionary(entries))
    }

    // MARK: - Public
    // MARK: - Private
}
