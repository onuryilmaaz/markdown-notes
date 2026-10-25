import SwiftUI
import UIKit

/// The whole visual language is four surfaces and three inks. Every screen is
/// built out of these — nothing in the feature layer hard-codes a colour.
public enum PlainPalette {
    /// Page background — the grey the white cards float on.
    public static let ground = dynamic(light: 0xECECEE, dark: 0x000000)
    /// A floating card.
    public static let surface = dynamic(light: 0xFFFFFF, dark: 0x141416)
    /// A quiet fill inside a card (chips, unselected segments, avatars).
    public static let fill = dynamic(light: 0xF2F2F4, dark: 0x1F1F22)
    /// Reversed surface — black pills in light, white pills in dark.
    public static let emphasis = dynamic(light: 0x0A0A0B, dark: 0xF6F6F8)
    public static let onEmphasis = dynamic(light: 0xFFFFFF, dark: 0x0A0A0B)
    /// Code blocks stay ink-dark in both themes.
    public static let code = dynamic(light: 0x0A0A0B, dark: 0x000000)
    public static let onCode = dynamic(light: 0xF6F6F8, dark: 0xF6F6F8)

    public static let ink = dynamic(light: 0x101012, dark: 0xF6F6F8)
    public static let inkSecondary = dynamic(light: 0x6B6B70, dark: 0x9A9AA0)
    public static let inkTertiary = dynamic(light: 0xA6A6AC, dark: 0x6A6A70)
    public static let hairline = dynamic(light: 0xEAEAEC, dark: 0x28282C)
    public static let dotIdle = dynamic(light: 0xDCDCE0, dark: 0x35353A)
    public static let destructive = dynamic(light: 0xE5484D, dark: 0xFF6369)

    public static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
