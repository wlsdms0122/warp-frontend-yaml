//
//  OriginPositionTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

// Every node of a spent tree stands somewhere in the text: where the text
// wrote it, or, for a node a pass made, where the text wrote what it was made
// from. Walked over the examples' programs and over texts that make each kind
// of node the text did not write.
@Suite("Every node of a spent tree carries a position")
struct OriginPositionTests {
    // MARK: - Property
    private let frontend: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.frontend = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("each example program's documents, spent together, carry a position at every node", arguments: [
        "flow",
        "sheet"
    ])
    func anExampleProgramIsPositioned(program: String) throws {
        // Given
        let example = try ExampleProgram(program)

        // When
        let sut = try frontend.documents(from: try example.texts())

        // Then
        #expect(example.files.isEmpty == false)

        for (file, spent) in zip(example.files, sut) {
            #expect(unpositioned(in: spent.origin.document) == [], "\(file.lastPathComponent)")
        }
    }

    @Test("a text that makes a node the text did not write carries a position at every node", arguments: [
        // A procedure's defaults, bound before its body.
        """
        name: App
        procedures:
          wait:
            parameters:
              - label:
                  type: String
                  default: idle
              - timeout:
                  type: Int
                  default: { of: 30, plus: 1 }
            body:
              - let: waited
                value: { ref: timeout }
            result: { ref: waited }
        """,
        // `cases`, its arms nested in each other's `else`.
        """
        name: App
        procedures:
          entry:
            parameters: [ n: Int ]
            body:
              - value:
                  cases:
                    - when: { of: { ref: n }, is: 1 }
                      then: []
                    - when: { of: { ref: n }, is: 2 }
                      then:
                        - let: q
                          value: a
                    - else:
                        - let: r
                          value: b
        """,
        // `each`, with the position bound beside the element.
        """
        name: App
        procedures:
          entry:
            parameters: [ words: "Array<String>" ]
            body:
              - let: walk
                value:
                  each:
                    of: { ref: words }
                    as: word
                    index: i
                    body:
                      - let: q
                        value: { ref: word }
        """,
        // Operator mappings: one key alone, a subject beside a key, an
        // operand the form fixes.
        """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            returns: Bool
            body:
              - let: n
                value:
                  count: 5
              - let: out
                value:
                  of: a
                  pair: b
              - let: spin
                value:
                  loop:
                    while:
                      of: 1
                      greaterThan: 0
                    body: []
            result:
              present:
                call:
                  procedure: pair
                  arguments: [ a, b ]
        """,
        // A template's pieces.
        """
        name: Demo
        procedures:
          entry:
            parameters: [ who: String ]
            body:
              - let: said
                value: { format: "hi ${name}!", with: { name: { ref: who } } }
        """,
        // Arguments written by name, an Optional left out.
        """
        name: App
        procedures:
          inner:
            const: true
            parameters: [ x: Int, y: Int, z: Int? ]
            returns: Int
            result: { ref: x }
          entry:
            returns: Int
            body:
              - let: r
                value:
                  call:
                    procedure: inner
                    arguments:
                      y: 1
                      x: 2
            result: { ref: r }
        """,
        // `result:` of a procedure and of a closure.
        """
        name: App
        procedures:
          entry:
            returns: String
            body:
              - let: f
                value:
                  closure:
                    returns: String
                    result: a
            result: b
        """,
        // A closure completed from its slot: a connective's side, and an
        // operand under `map`.
        """
        name: App
        procedures:
          flag:
            const: true
            parameters: [ x: String ]
            returns: Bool
            result: true
          entry:
            returns: Bool
            body:
              - let: out
                value:
                  of: [ a, b ]
                  map:
                    closure:
                      parameters: [ s: String ]
                      returns: String
                      result: { ref: s }
              - let: ok
                value:
                  all_of:
                    - true
                    - call:
                        procedure: flag
                        arguments: [ a ]
            result: { ref: ok }
        """,
        // `imports` and `warp`, written for the document as a whole.
        """
        name: Demo
        procedures:
          entry:
            returns: String
            result: { of: [ a, b ], joined: "" }
        """
    ])
    func anImplicitNodeIsPositioned(text: String) throws {
        // When
        let sut = try frontend.document(from: text).origin.document

        // Then
        #expect(unpositioned(in: sut) == [])
    }

    // MARK: - Public
    // MARK: - Private
    // The steps to each node of `tree` that carries no position, written as
    // the spec writes a place, keys and positions joined by `/`.
    private func unpositioned(in tree: Tree, at steps: [String] = []) -> [String] {
        let here = tree.position == nil ? [steps.joined(separator: "/")] : []

        switch tree.content {
        case let .array(elements):
            return here + elements.enumerated().flatMap { index, element in
                unpositioned(in: element, at: steps + ["\(index)"])
            }

        case let .dictionary(entries):
            return here + entries.sorted { first, second in first.key < second.key }.flatMap { key, entry in
                unpositioned(in: entry, at: steps + [key])
            }

        case .null, .bool, .int, .double, .string:
            return here
        }
    }
}
