//
//  ScopeTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import WarpYAML

// The value names a place reads: the parameters around it, what the
// statements before it introduce, and what a construct around it binds for
// the part it is in.
@Suite("The names a place reads")
struct ScopeTests {
    // MARK: - Property
    private let frontend: YAMLFrontend

    private let written = """
    name: Demo
    procedures:
      entry:
        parameters:
          - count: Int
          - maybe: Int?
        body:
          - let: first
            value: 1
          - let: spin
            value:
              loop:
                while: { ref: count }
                body:
                  - let: inside
                    value: 2
                  - value: 3
          - let: got
            value:
              unwrap:
                of: { ref: maybe }
                then:
                  - value: 4
          - let: held
            value:
              unwrap:
                of: { ref: maybe }
          - let: tried
            value:
              try:
                body:
                  - value: 5
                catch:
                  - value: 6
          - value:
              call:
                procedure: run
                arguments:
                  - closure:
                      parameters: [ item: Int ]
                      body:
                        - value: 7
          - value: 8
      run:
        parameters: [ work: "(Int) -> Null" ]
    """

    // MARK: - Initializer
    init() throws {
        self.frontend = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a place reads the names around it and before it, and a construct's binding in its own part alone", arguments: [
        ([0], ["count", "maybe"]),
        ([1, "value", "loop", "while"], ["count", "first", "maybe", "spin"]),
        ([1, "value", "loop", "body", 1], ["count", "first", "inside", "maybe", "spin"]),
        ([2, "value", "unwrap", "then", 0], ["count", "first", "got", "maybe"]),
        ([4, "value", "try", "body", 0], ["count", "first", "held", "maybe"]),
        ([4, "value", "try", "catch", 0], ["count", "first", "held", "maybe", "tried"]),
        ([5, "value", "call", "arguments", 0, "closure", "body", 0], ["count", "first", "held", "item", "maybe"]),
        ([6], ["count", "first", "held", "maybe"])
    ] as [([Origin.Step], [String])])
    func aPlaceReadsTheNamesInScope(steps: [Origin.Step], names: [String]) throws {
        // Given
        let document = try frontend.document(from: written).origin.document

        // When
        let sut = Scope(of: document, at: ["procedures", "Demo.entry", "body"] + steps)

        // Then
        #expect(sut.names.map(\.spelling) == names)
    }

    @Test("a switch's arm reads what it binds in its `then`")
    func anArmReadsWhatItBinds() throws {
        // Given
        let text = """
        name: Demo
        types:
          Link:
            enum: { local: {}, remote: { port: Int } }
        procedures:
          entry:
            parameters: [ link: Link ]
            body:
              - value:
                  switch:
                    of: { ref: link }
                    cases:
                      remote:
                        binds: { port: p }
                        then:
                          - value: 1
                    default: []
        """
        let document = try frontend.document(from: text).origin.document
        let arm: [Origin.Step] = ["procedures", "Demo.entry", "body", 0, "value", "switch", "cases", "remote"]

        // When
        let sut = Scope(of: document, at: arm + ["then", 0])

        // Then
        #expect(sut.names.map(\.spelling) == ["link", "p"])
    }

    // MARK: - Public
    // MARK: - Private
}
