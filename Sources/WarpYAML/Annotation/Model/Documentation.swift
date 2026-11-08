//
//  Documentation.swift
//  WarpYAML
//
//  Created by JSilver on 10/24/26.
//

import Foundation

// The prose a text writes about its procedures, which the document does not
// hold, handed back beside it by the names the document declares them by.
public struct Documentation: Sendable, Equatable {
    // MARK: - Property
    // Each procedure's description, by the procedure's full name.
    public let descriptions: [Name: String]

    // Each parameter's hint, by the procedure's full name and the
    // parameter's name.
    public let hints: [Name: [Name: String]]

    // MARK: - Initializer
    init(descriptions: [Name: String], hints: [Name: [Name: String]]) {
        self.descriptions = descriptions
        self.hints = hints
    }

    // MARK: - Public
    // MARK: - Private
}
