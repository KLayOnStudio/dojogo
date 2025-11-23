import SwiftUI

extension Font {
    // MARK: - Pixelify Sans Font

    static func pixelify(size: CGFloat, weight: PixelifyWeight = .regular) -> Font {
        // Check if font is available, fallback to monospaced if not
        if UIFont(name: weight.fontName, size: size) != nil {
            return Font.custom(weight.fontName, size: size)
        } else {
            // Fallback to monospaced system font
            print("⚠️ Pixelify font '\(weight.fontName)' not found, using monospaced fallback")
            switch weight {
            case .regular:
                return Font.system(size: size, design: .monospaced)
            case .semiBold:
                return Font.system(size: size, weight: .semibold, design: .monospaced)
            case .bold:
                return Font.system(size: size, weight: .bold, design: .monospaced)
            }
        }
    }

    // Predefined sizes for consistency
    static var pixelifyTitle: Font {
        return .pixelify(size: 32, weight: .bold)
    }

    static var pixelifyHeadline: Font {
        return .pixelify(size: 24, weight: .semiBold)
    }

    static var pixelifySubheadline: Font {
        return .pixelify(size: 20, weight: .semiBold)
    }

    static var pixelifyBody: Font {
        return .pixelify(size: 16, weight: .regular)
    }

    static var pixelifyBodyBold: Font {
        return .pixelify(size: 16, weight: .bold)
    }

    static var pixelifyCaption: Font {
        return .pixelify(size: 14, weight: .regular)
    }

    static var pixelifySmall: Font {
        return .pixelify(size: 12, weight: .regular)
    }

    // Button sizes
    static var pixelifyButton: Font {
        return .pixelify(size: 18, weight: .semiBold)
    }

    static var pixelifyButtonLarge: Font {
        return .pixelify(size: 22, weight: .bold)
    }
}

enum PixelifyWeight {
    case regular
    case semiBold
    case bold

    var fontName: String {
        // For now, use only Regular and let the system handle bold/semibold
        return "PixelifySans-Regular"
    }
}