import Foundation

enum InventoryRFC8785Canonicalizer {
    static func data(from value: Any) throws -> Data {
        var output = ""
        try append(value, to: &output)
        guard let data = output.data(using: .utf8) else {
            throw InventoryPortabilityCodecError.invalidSchema
        }
        return data
    }

    private static func append(_ value: Any, to output: inout String) throws {
        switch value {
        case is NSNull:
            output += "null"
        case let string as String:
            append(string: string, to: &output)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                output += number.boolValue ? "true" : "false"
            } else {
                // Version 1 has integer-only numeric fields, so unsupported floating encodings fail closed.
                guard !CFNumberIsFloatType(number),
                      number.stringValue.range(of: #"^-?(0|[1-9][0-9]*)$"#, options: .regularExpression) != nil
                else { throw InventoryPortabilityCodecError.invalidSchema }
                output += number.stringValue
            }
        case let array as [Any]:
            output += "["
            for index in array.indices {
                if index > array.startIndex { output += "," }
                try append(array[index], to: &output)
            }
            output += "]"
        case let object as [String: Any]:
            output += "{"
            let keys = object.keys.sorted(by: utf16Precedes)
            for index in keys.indices {
                if index > keys.startIndex { output += "," }
                let key = keys[index]
                append(string: key, to: &output)
                output += ":"
                guard let member = object[key] else {
                    throw InventoryPortabilityCodecError.invalidSchema
                }
                try append(member, to: &output)
            }
            output += "}"
        default:
            throw InventoryPortabilityCodecError.invalidSchema
        }
    }

    private static func utf16Precedes(_ lhs: String, _ rhs: String) -> Bool {
        // RFC 8785 orders object member names by raw UTF-16 code units.
        Array(lhs.utf16).lexicographicallyPrecedes(Array(rhs.utf16))
    }

    private static func append(string: String, to output: inout String) {
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x08:
                output += #"\b"#
            case 0x09:
                output += #"\t"#
            case 0x0A:
                output += #"\n"#
            case 0x0C:
                output += #"\f"#
            case 0x0D:
                output += #"\r"#
            case 0x00...0x1F:
                output += String(format: #"\u%04x"#, scalar.value)
            case 0x22:
                output += #"\""#
            case 0x5C:
                output += #"\\"#
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }
}
