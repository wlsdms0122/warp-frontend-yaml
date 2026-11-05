//
//  ExampleProgram.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import WarpYAML

// A program of the package's `example/` folder: its YAML texts in file-name
// order, the order they are spent together in, beside the `.warp` bytes
// `warp-yaml` wrote for them, the program's name with `.warp`, and the module
// `Host`, the vocabulary the specification's examples are lent, which they
// use.
struct ExampleProgram {
    // MARK: - Property
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    let files: [URL]

    // The document the texts are spent into.
    private let document: URL

    // MARK: - Initializer
    init(_ name: String) throws {
        let folder = Self.root
            .appending(path: "example")
            .appending(path: name)

        self.document = folder.appending(path: name).appendingPathExtension("warp")
        self.files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { file in file.pathExtension == "yaml" }
            .sorted { first, second in first.lastPathComponent < second.lastPathComponent }
    }

    // MARK: - Public
    // A front end depending on the module `Host`, read from the interface the
    // specification's examples give.
    static func frontend() throws -> YAMLFrontend {
        let host = try Data(contentsOf: root.appending(path: "warp/example/host.interface.warpt"))

        return try YAMLFrontend().depending(on: [.interface(host, module: "Host")])
    }

    func texts() throws -> [String] {
        try files.map { file in try String(contentsOf: file, encoding: .utf8) }
    }

    // The bytes written beside the texts.
    func golden() throws -> Data {
        try Data(contentsOf: document)
    }

    // MARK: - Private
}
