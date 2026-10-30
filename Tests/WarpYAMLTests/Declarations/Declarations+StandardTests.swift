//
//  Declarations+StandardTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("Standard's declarations are its interface's")
struct DeclarationsStandardTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the baked interface is the bytes of the IR's interface file")
    func theBakedInterfaceIsTheFile() throws {
        // Given
        let file = try Data(contentsOf: Self.standardInterface)

        // When
        let sut = Data(Declarations.standardInterface.utf8)

        // Then
        #expect(sut == file)
    }

    @Test("Standard's procedures are named by their short names")
    func standardsShortNames() throws {
        // Given
        let sut = try Declarations.standard()

        // When
        let append = try sut.qualified("append", in: .procedure)
        let map = sut.declarations(named: "map", in: .procedure)
        let member = try sut.qualified("Int.plus", in: .procedure)
        let requirement = try sut.qualified("plus", in: .procedure)

        // Then
        #expect(append == "Standard.Collection.append")
        #expect(map == ["Standard.Collection.map", "Standard.Concurrent.map"])
        #expect(member == "Int.plus")
        #expect(requirement == "Standard.Numeric.plus")
        #expect(try sut.qualified("Comparable", in: .type) == "Standard.Comparable")
        #expect(
            sut.signature(of: "Standard.Optional.unwrapped")?.parameters.map(\.type?.spelling)
                == ["some Wrapped?", "const isolated () -> some Wrapped"]
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static var standardInterface: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../warp/lib/standard/interface/standard.interface.warpt")
            .standardized
    }
}
