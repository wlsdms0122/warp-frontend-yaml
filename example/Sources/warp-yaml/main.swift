//
//  main.swift
//  warp-yaml
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import WarpYAML

// warp-yaml <text.yaml>...
//
// The texts are spent together, so each names the others' declarations as
// its own, and each text's document is written beside it as `.warp` bytes,
// `main.warp` for `main.yaml`. A refusal goes to standard error as
// `<file>:<line>:<column>: <message>`, the file the text it stands in, and
// nothing is written.

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(status)
}

let files = CommandLine.arguments.dropFirst().map { path in URL(filePath: path) }

guard !files.isEmpty else {
    fail("usage: warp-yaml <text.yaml>...", status: 2)
}

let texts = files.map { file in
    do {
        return try String(contentsOf: file, encoding: .utf8)
    } catch {
        fail("\(file.relativePath): \(error.localizedDescription)", status: 1)
    }
}

do {
    let spent = try YAMLFrontend().documents(from: texts)

    for (file, written) in zip(files, spent) {
        try written.document.write(
            to: file.deletingPathExtension().appendingPathExtension("warp"),
            options: .atomic
        )
    }
} catch let refusal as AuthoringError {
    guard let text = refusal.text else { fail("warp-yaml: \(refusal)", status: 1) }

    let file = files[text].relativePath

    guard let position = refusal.position else { fail("\(file): \(refusal.message)", status: 1) }

    fail("\(file):\(position): \(refusal.message)", status: 1)
} catch {
    fail("warp-yaml: \(error.localizedDescription)", status: 1)
}
