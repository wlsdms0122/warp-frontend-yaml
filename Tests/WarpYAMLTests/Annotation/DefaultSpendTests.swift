//
//  DefaultSpendTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A parameter's default, spent into an Optional parameter and a binding")
struct DefaultSpendTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a defaulted parameter reads T?, and its binding stands first in the body, in the parameters' order")
    func aDefaultIsABinding() throws {
        // Given. A parameter of any type writes no type on its binding, and a
        // procedure with no body is given one
        let text = """
        procedures:
          Lib.say:
            parameters:
              - words: String
              - echo: { default: x }
              - timeout: { type: Int, default: 30 }
            body: [ { value: { ref: words } } ]
        types:
          Lib.Box:
            procedures: { grown: { parameters: [ by: { type: Int, default: 1 } ] } }
        """

        // When
        let spent = try defaulted(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          Lib.say:
            parameters: [ { name: words, type: String }, { name: echo, type: Any? }, { name: timeout, type: Int? } ]
            body:
              - \(binding("echo", type: nil, default: "x"))
              - \(binding("timeout", type: "Int", default: "30"))
              - { value: { ref: words } }
        types:
          Lib.Box:
            procedures:
              grown:
                parameters: [ { name: by, type: Int? } ]
                body: [ \(binding("by", type: "Int", default: "1")) ]
        """)))
    }

    @Test("a default's own shorthands are spent with the body it stands in")
    func aDefaultsShorthandsAreSpent() throws {
        // Given
        let text = """
        procedures:
          f:
            parameters: [ make: { type: "() -> Int", default: { closure: { result: { of: 1, plus: 2 } } } } ]
        """

        // When
        let spent = try defaulted(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          f:
            parameters: [ { name: make, type: "(() -> Int)?" } ]
            body:
              - \(binding("make", type: "\"() -> Int\"", default: """
                { closure: { body: [ { value: { return: { call: { procedure: Standard.Numeric.plus, arguments: [ 1, 2 ] } } } } ] } }
                """))
        """)))
    }

    @Test("the binding stands where the parameter is written, and the default where the text wrote it")
    func theBindingStandsAtTheParameter() throws {
        // Given
        let text = """
        procedures:
          f:
            parameters: [ by: { type: Int, default: 1 } ]
        """

        // When
        let binding = try defaulted(text)["procedures"]?["f"]?["body"]?.arrayValue?.first
        let closure = binding?["value"]?["call"]?["arguments"]?.arrayValue?.last?["closure"]
        let returned = closure?["body"]?.arrayValue?.first?["value"]?["return"]

        // Then
        #expect(binding?.position == Origin.Position(line: 3, column: 19))
        #expect(binding?.isImplicit == true)
        #expect(returned?.position == Origin.Position(line: 3, column: 36))
        #expect(returned?.isImplicit == false)
    }

    // MARK: - Public
    // MARK: - Private
    // The text through its naming and its annotation, its defaults, then
    // its statement and expression shorthands.
    private func defaulted(_ text: String) throws -> Tree {
        let parsed = try parser.parse(text)
        let naming = try Naming(of: parsed, leaningOn: Declarations())
        let annotation = try Annotation(of: try naming.prefixed(parsed), reading: naming)

        return try Grammar().rewriting(
            try annotation.defaulted(annotation.document),
            [StatementSugar().rewritten, ExpressionSugar(reading: naming).rewritten]
        )
    }

    // The statement binding `name` to what it was handed or `default`.
    private func binding(_ name: String, type: String?, default written: String) -> String {
        let declared = type.map { type in " type: \(type)," } ?? ""
        let otherwise = "{ closure: { returns: \(type ?? "Any"), body: [ { value: { return: \(written) } } ] } }"

        return "{ let: \(name),\(declared) value: { call: { procedure: Standard.Optional.unwrapped, "
            + "arguments: [ { ref: \(name) }, \(otherwise) ] } } }"
    }
}
