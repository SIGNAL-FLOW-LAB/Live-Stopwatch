import SwiftUI

enum SFFont {
    static func title(_ size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: .semibold,
            design: .default
        )
    }

    static func body(_ size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: .regular,
            design: .default
        )
    }

    static func timer(_ size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: .bold,
            design: .default
        )
        .monospacedDigit()
    }

    static func caption(_ size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: .regular,
            design: .default
        )
    }
}
