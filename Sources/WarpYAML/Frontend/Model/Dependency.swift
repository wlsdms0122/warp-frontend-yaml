//
//  Dependency.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a text may use beside `Standard`: a part of a module, by the name a
// text's `uses:` writes it by. A YAML text's declarations are read off it,
// and a declaration file declares them the way `Standard`'s does. Every
// dependency handed under one name is one module.
public enum Dependency: Sendable {
    case text(String, module: Name)
    case interface(Data, module: Name)
}
