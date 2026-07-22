import SwiftUI

enum InventoryTagStyle {
    enum TintToken: String, CaseIterable {
        case blue
        case teal
        case green
        case orange
        case purple
        case pink
        case indigo
        case cyan

        var color: Color {
            switch self {
            case .blue:
                .blue
            case .teal:
                .teal
            case .green:
                .green
            case .orange:
                .orange
            case .purple:
                .purple
            case .pink:
                .pink
            case .indigo:
                .indigo
            case .cyan:
                .cyan
            }
        }
    }

    static func tint(for tag: String) -> Color {
        tintToken(for: tag).color
    }

    static func tintToken(for tag: String) -> TintToken {
        let index = stablePaletteIndex(for: normalizedTag(tag))
        return TintToken.allCases[index]
    }

    static func normalizedTag(_ tag: String) -> String {
        tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func stablePaletteIndex(for normalizedTag: String) -> Int {
        guard !normalizedTag.isEmpty else {
            return 0
        }

        let hash = normalizedTag.unicodeScalars.reduce(UInt32(2_166_136_261)) { partialResult, scalar in
            (partialResult ^ scalar.value) &* 16_777_619
        }

        return Int(hash % UInt32(TintToken.allCases.count))
    }
}
