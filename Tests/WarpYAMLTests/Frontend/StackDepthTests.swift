//
//  StackDepthTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
import WarpYAML

// The deepest texts each walk meets, spent from a test's own thread. A walk
// whose frames grow past the stack a spend runs on traps here.
@Suite("The stack a spend takes")
struct StackDepthTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a text nested to the bound spends from any thread, written or refused", arguments: [
        // A connective's sides, each a closure: the deepest the shorthands
        // make a text within the bound.
        Self.result(nesting: "{ all_of: [ true, ", "true", " ] }", 62),
        Self.result(nesting: "{ of: 1, plus: ", "1", " }", 125),
        Self.result(nesting: "{ closure: { result: ", "1", " } }", 62),
        Self.result(nesting: "[", "1", "]", 125),
        Self.cases(31),
        // A text the YAML parse composes before the bound is met, about as
        // deep as it composes one.
        Self.result(nesting: "{ a: ", "1", " }", 996)
    ])
    func aTextNestedToTheBoundSpends(text: String) {
        // Given. The argument's text

        // When
        let spent = Result { try sut.document(from: text) }

        // Then
        if case let .failure(refusal) = spent {
            #expect(refusal is AuthoringError)
        }
    }

    @Test("an interface nested to the bound reads from any thread")
    func anInterfaceNestedToTheBoundReads() {
        // Given. A procedure type in its returns, 128 levels and 257 lists
        let type = String(repeating: "(procedure (parameters) (returns ", count: 128)
            + "Int"
            + String(repeating: "))", count: 128)
        let interface = Data("(interface 1)\n(type App.T \(type))".utf8)

        // When
        let read = Result { try sut.leaning(on: [.interface(interface)]) }

        // Then
        #expect(throws: Never.self) { try read.get() }
    }

    // MARK: - Public
    // MARK: - Private
    // A procedure whose result nests `count` times, `open` and `close`
    // around `inner`.
    private static func result(nesting open: String, _ inner: String, _ close: String, _ count: Int) -> String {
        """
        name: App
        procedures:
          entry:
            returns: Any
            result: \(String(repeating: open, count: count) + inner + String(repeating: close, count: count))
        """
    }

    // A procedure whose body holds one `cases` of `count` cases and an
    // `else`.
    private static func cases(_ count: Int) -> String {
        """
        name: App
        procedures:
          entry:
            returns: Int
            body:
              - value:
                  cases:
        \(String(repeating: "            - { when: true, then: [] }\n", count: count))\
                    - else: []
            result: 1
        """
    }
}
