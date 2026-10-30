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
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("each example text is spent into the bytes of the .warp file beside it", arguments: [
        "flow",
        "sheet"
    ])
    func anExampleIsSpentIntoItsGolden(program: String) throws {
        // Given
        let example = try ExampleProgram(program)
        let goldens = try example.goldens()

        // When
        let spent = try sut.documents(from: try example.texts())

        // Then
        #expect(example.files.isEmpty == false)
        #expect(spent.count == goldens.count)

        for (file, (written, golden)) in zip(example.files, zip(spent, goldens)) {
            #expect(written.document == golden, "\(file.lastPathComponent)")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
