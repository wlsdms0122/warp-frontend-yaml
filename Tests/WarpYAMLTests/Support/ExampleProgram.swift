//
//  ExampleProgram.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A program of the package's `example/` folder: its YAML texts in file-name
// order, the order they are spent together in, each beside the `.warp`
// bytes `warp-yaml` wrote for it.
struct ExampleProgram {
    // MARK: - Property
    let files: [URL]

    // MARK: - Initializer
    init(_ name: String) throws {
        let folder = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "example")
            .appending(path: name)

        self.files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { file in file.pathExtension == "yaml" }
            .sorted { first, second in first.lastPathComponent < second.lastPathComponent }
    }

    // MARK: - Public
    func texts() throws -> [String] {
        try files.map { file in try String(contentsOf: file, encoding: .utf8) }
    }

    // The bytes written beside each text, in the texts' order.
    func goldens() throws -> [Data] {
        try files.map { file in try Data(contentsOf: file.deletingPathExtension().appendingPathExtension("warp")) }
    }

    // MARK: - Private
}
