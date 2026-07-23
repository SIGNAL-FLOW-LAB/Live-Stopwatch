import SwiftUI

// MARK: - SIGNAL FLOW Theme

enum SFTheme {

    // MARK: Colors

    static let background = Color.black

    static let mint = Color(
        red: 102/255,
        green: 245/255,
        blue: 182/255
    )

    static let white = Color.white

    static let warning = Color.red

    static let secondary = Color.gray.opacity(0.65)

    // MARK: Spacing

    static let cornerRadius: CGFloat = 18

    static let padding: CGFloat = 24

    static let sectionSpacing: CGFloat = 36
}
