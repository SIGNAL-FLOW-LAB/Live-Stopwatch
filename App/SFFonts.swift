import SwiftUI

// MARK: - SIGNAL FLOW Fonts

enum SFFont {

    // タイトル
    static func title(_ size: CGFloat) -> Font {
        .custom("Outfit", size: size)
            .weight(.bold)
    }

    // 通常文字
    static func body(_ size: CGFloat) -> Font {
        .custom("Outfit", size: size)
    }

    // 数字（Show Timeと共通）
    static func timer(_ size: CGFloat) -> Font {
        .system(
            size: size,
            weight: .bold,
            design: .rounded
        )
        .monospacedDigit()
    }

    // 小さいラベル
    static func caption(_ size: CGFloat) -> Font {
        .custom("Outfit", size: size)
            .weight(.medium)
    }
}
