//
//  ElementReader.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The text's first layer: UTF-8 bytes into atoms and lists, knowing nothing
// of what a list means. Layout is free between tokens; the spelling of a
// value is not, so a number, a string or bytes written other than its one
// spelling is refused, each refusal at the line and column it stood at.
struct ElementReader {
    // MARK: - Property
    // How deep lists nest, the outermost the first.
    private static let depthBound = 257

    private static let whiteSpace: Set<Unicode.Scalar> = [" ", "\t", "\n", "\r"]

    // What ends a bare token besides white space.
    private static let delimiters: Set<Unicode.Scalar> = ["(", ")", "\"", "`"]

    private static let shortEscapes: [Unicode.Scalar: Unicode.Scalar] = ["\\": "\\", "n": "\n", "r": "\r", "t": "\t"]

    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var line = 1
    private var column = 1

    // MARK: - Initializer
    init(_ text: Data) throws(AuthoringError) {
        guard let decoded = String(data: text, encoding: .utf8) else {
            throw AuthoringError("the text is no UTF-8")
        }

        self.scalars = Array(decoded.unicodeScalars)
    }

    // MARK: - Public
    // Every element at the top of the text, in order. The lists opened and
    // not yet closed are held on a stack, each with where it began, so a
    // text nesting deep is read without recursion.
    mutating func read() throws(AuthoringError) -> [Element] {
        var top: [Element] = []
        var open: [(elements: [Element], start: Origin.Position)] = []

        skipWhiteSpace()

        while let current {
            let start = position
            let element: Element

            switch current {
            case "(":
                guard open.count < Self.depthBound else {
                    throw AuthoringError("lists nest at most \(Self.depthBound) deep", at: start)
                }

                advance()
                open.append(([], start))
                skipWhiteSpace()
                continue

            case ")":
                guard let list = open.popLast() else { throw AuthoringError("')' closes no list", at: start) }

                advance()
                element = .list(list.elements, at: list.start)

            default:
                element = .atom(try atom(), at: start)
            }

            if let next = self.current, !Self.whiteSpace.contains(next), next != "(", next != ")" {
                throw AuthoringError("a token runs straight into the next, with no white space between", at: position)
            }

            if open.isEmpty {
                top.append(element)
            } else {
                open[open.count - 1].elements.append(element)
            }

            skipWhiteSpace()
        }

        if let unclosed = open.last {
            throw AuthoringError("the text ends inside a list", at: unclosed.start)
        }

        return top
    }

    // MARK: - Private
    private var position: Origin.Position {
        Origin.Position(line: line, column: column)
    }

    private var current: Unicode.Scalar? {
        index < scalars.count ? scalars[index] : nil
    }

    private var next: Unicode.Scalar? {
        index + 1 < scalars.count ? scalars[index + 1] : nil
    }

    private mutating func atom() throws(AuthoringError) -> Atom {
        switch current {
        case "\"": .string(try quoted(by: "\""))
        case "`": try name()
        case "x" where next == "\"": .bytes(try bytes())
        default: try bare()
        }
    }

    // A token written bare: a number, `null`, `true`, `false` or a name.
    private mutating func bare() throws(AuthoringError) -> Atom {
        let start = position
        var token = String.UnicodeScalarView()

        while let current, !Self.whiteSpace.contains(current), !Self.delimiters.contains(current) {
            guard current.value >= 0x20 else {
                throw AuthoringError("a control character is written in a name", at: position)
            }

            token.append(current)
            advance()
        }

        let spelling = String(token)

        if let first = token.first, Self.beginsNumber(first, then: token.dropFirst().first) {
            return try number(spelling, at: start)
        }

        return switch spelling {
        case "null": .null
        case "true": .bool(true)
        case "false": .bool(false)
        default: .name(spelling)
        }
    }

    // A number in its one spelling: an integer with no point or exponent, a
    // floating-point literal with one.
    private func number(_ spelling: String, at start: Origin.Position) throws(AuthoringError) -> Atom {
        guard spelling.contains(where: { character in character == "." || character == "e" || character == "E" }) else {
            guard let int = Int(spelling), String(int) == spelling else {
                throw AuthoringError("'\(spelling)' is no number", at: start)
            }

            return .int(int)
        }

        guard let double = Double(spelling), double.isFinite, Self.spelling(of: double) == spelling else {
            throw AuthoringError("'\(spelling)' is no number", at: start)
        }

        return .double(double)
    }

    // A name in backticks.
    private mutating func name() throws(AuthoringError) -> Atom {
        let start = position
        let name = try quoted(by: "`")

        guard !name.isEmpty else { throw AuthoringError("a name in backticks holds one character or more", at: start) }

        return .name(name)
    }

    // What stands between two of `quote`, its escapes read: `\` before the
    // quote, `\\`, `\n`, `\r`, `\t`, and `\u` with four lowercase hex digits
    // for any other control character. Nothing else is escaped.
    private mutating func quoted(by quote: Unicode.Scalar) throws(AuthoringError) -> String {
        let start = position
        var text = String.UnicodeScalarView()

        advance()

        while current != quote {
            guard let current else { throw AuthoringError("the text ends inside a quote", at: start) }
            guard current.value >= 0x20 else {
                throw AuthoringError("a control character is written raw; it is escaped", at: position)
            }

            guard current == "\\" else {
                text.append(current)
                advance()
                continue
            }

            text.append(try escape(in: quote))
        }

        advance()

        return String(text)
    }

    private mutating func escape(in quote: Unicode.Scalar) throws(AuthoringError) -> Unicode.Scalar {
        let start = position

        advance()

        guard let escaped = current else { throw AuthoringError("the text ends inside an escape", at: start) }

        advance()

        if escaped == quote { return quote }
        if let short = Self.shortEscapes[escaped] { return short }

        guard escaped == "u" else { throw AuthoringError("'\\\(escaped)' is no escape", at: start) }

        var hex = ""

        for _ in 0..<4 {
            guard let digit = current, Self.isLowercaseHex(digit) else {
                throw AuthoringError("'\\u' takes four lowercase hex digits", at: start)
            }

            hex.unicodeScalars.append(digit)
            advance()
        }

        guard
            let value = UInt32(hex, radix: 16),
            value < 0x20,
            let scalar = Unicode.Scalar(value),
            !Self.shortEscapes.values.contains(scalar)
        else {
            throw AuthoringError("'\\u\(hex)' escapes what is written another way", at: start)
        }

        return scalar
    }

    // `x"…"`: lowercase hex, two digits a byte.
    private mutating func bytes() throws(AuthoringError) -> [UInt8] {
        let start = position
        var bytes: [UInt8] = []

        advance()
        advance()

        while current != "\"" {
            guard
                let high = current,
                let low = next,
                Self.isLowercaseHex(high),
                Self.isLowercaseHex(low),
                let byte = UInt8("\(high)\(low)", radix: 16)
            else {
                throw AuthoringError("bytes are lowercase hex, two digits a byte", at: start)
            }

            bytes.append(byte)
            advance()
            advance()
        }

        advance()

        return bytes
    }

    private mutating func skipWhiteSpace() {
        while let current, Self.whiteSpace.contains(current) {
            advance()
        }
    }

    // One scalar on. A line ends at a line feed, a carriage return, or the
    // two together.
    private mutating func advance() {
        let passed = scalars[index]

        index += 1

        guard passed == "\n" || (passed == "\r" && current != "\n") else {
            column += 1
            return
        }

        line += 1
        column = 1
    }

    private static func beginsNumber(_ first: Unicode.Scalar, then second: Unicode.Scalar?) -> Bool {
        guard first == "-" || first == "+" else { return isDigit(first) }

        return second.map(isDigit) ?? false
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
    }

    private static func isLowercaseHex(_ scalar: Unicode.Scalar) -> Bool {
        isDigit(scalar) || ("a"..."f").contains(scalar)
    }

    // A floating-point number's one spelling: the shortest digits that read
    // back to the same binary64, in the point form when its decimal exponent
    // k is -5 < k < 16, and otherwise in the exponent form with a sign and at
    // least two digits.
    private static func spelling(of double: Double) -> String {
        let signed = double.sign == .minus ? "-" : ""

        guard double != 0 else { return signed + "0.0" }

        let shortest = "\(double.magnitude)".split(separator: "e", maxSplits: 1)
        let written = shortest.count == 2 ? Int(shortest[1]) ?? 0 : 0
        let halves = shortest[0].split(separator: ".", maxSplits: 1)
        let whole = halves[0]
        var digits = Array(whole + (halves.count == 2 ? halves[1] : ""))
        let leading = digits.prefix { digit in digit == "0" }.count

        digits.removeFirst(leading)

        while digits.last == "0" {
            digits.removeLast()
        }

        let exponent = whole.count - 1 - leading + written

        guard exponent > -5, exponent < 16 else {
            let tail = digits.count > 1 ? "." + String(digits[1...]) : ""

            return signed + String(digits[0]) + tail + "e" + String(format: "%+03d", exponent)
        }

        guard exponent >= 0 else {
            return signed + "0." + String(repeating: "0", count: -exponent - 1) + String(digits)
        }

        let count = exponent + 1
        let padded = digits + Array(repeating: "0", count: max(0, count - digits.count))
        let fraction = padded.count > count ? String(padded[count...]) : "0"

        return signed + String(padded[..<count]) + "." + fraction
    }
}
