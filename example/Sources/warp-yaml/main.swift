//
//  main.swift
//  warp-yaml
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import WarpYAML

// warp-yaml [--interface <module>=<file>]... -o <document.warp> <text.yaml>...
//
// The texts are spent together, one module, so each names the others'
// declarations as its own, and the module's document is written to the file
// `-o` names as `.warp` bytes. Each `--interface` hands a declaration file as
// a part of the module it names, for a text to use. Each refusal goes to
// standard error as `<file>:<line>:<column>: <message>`, the file the text it
// stands in, and nothing is written.

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(status)
}

// Each refusal a line, at the file `file` names for the text it stands in.
func fail(_ refused: TextRefused, in file: (Int?) -> String) -> Never {
    let lines = refused.refusals.map { refusal in
        let at = file(refusal.text)

        return refusal.position.map { position in "\(at):\(position): \(refusal.message)" } ?? "\(at): \(refusal.message)"
    }

    fail(lines.joined(separator: "\n"), status: 1)
}

let usage = "usage: warp-yaml [--interface <module>=<file>]... -o <document.warp> <text.yaml>..."
var arguments = CommandLine.arguments.dropFirst()
var interfaces: [(module: String, file: URL)] = []

while arguments.first == "--interface" {
    arguments.removeFirst()

    guard
        let given = arguments.popFirst(),
        let equals = given.firstIndex(of: "="),
        !given[..<equals].isEmpty,
        !given[given.index(after: equals)...].isEmpty
    else {
        fail(usage, status: 2)
    }

    interfaces.append((String(given[..<equals]), URL(filePath: String(given[given.index(after: equals)...]))))
}

guard arguments.popFirst() == "-o", let output = arguments.popFirst().map({ path in URL(filePath: path) }) else {
    fail(usage, status: 2)
}

let files = arguments.map { path in URL(filePath: path) }

guard !files.isEmpty else {
    fail(usage, status: 2)
}

let texts = files.map { file in
    do {
        return try String(contentsOf: file, encoding: .utf8)
    } catch {
        fail("\(file.relativePath): \(error.localizedDescription)", status: 1)
    }
}

let dependencies = interfaces.map { module, file in
    do {
        return Dependency.interface(try Data(contentsOf: file), module: try Name(module))
    } catch {
        fail("\(file.relativePath): \(error.localizedDescription)", status: 1)
    }
}

let frontend: YAMLFrontend

do {
    frontend = try YAMLFrontend().depending(on: dependencies)
} catch let refused as TextRefused {
    fail(refused) { text in text.map { position in interfaces[position].file.relativePath } ?? "warp-yaml" }
} catch {
    fail("warp-yaml: \(error.localizedDescription)", status: 1)
}

do {
    try frontend.document(from: texts).document.write(to: output, options: .atomic)
} catch let refused as TextRefused {
    fail(refused) { text in text.map { position in files[position].relativePath } ?? "warp-yaml" }
} catch {
    fail("warp-yaml: \(error.localizedDescription)", status: 1)
}
