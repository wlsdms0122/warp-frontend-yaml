//
//  Dependency.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a text leans on beside `Standard`: another YAML text, whose
// declarations are read off it, or a declaration file, a module declared the
// way `Standard`'s is.
public enum Dependency: Sendable {
    case text(String)
    case interface(Data)
}
