//
//  ExampleTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
import WarpYAML

// The examples' programs, each spent together, against the `.warp` files
// beside their texts.
@Suite("The example programs")
struct ExampleTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try ExampleProgram.frontend()
    }

    // MARK: - Test
    @Test("each example program's texts are spent into the bytes of the .warp file beside them", arguments: [
        "flow",
        "sheet"
    ])
    func anExampleIsSpentIntoItsGolden(program: String) throws {
        // Given
        let example = try ExampleProgram(program)
        let golden = try example.golden()

        // When
        let spent = try sut.document(from: try example.texts())

        // Then
        #expect(example.files.isEmpty == false)
        #expect(spent.document == golden)
    }

    // MARK: - Public
    // MARK: - Private
}
