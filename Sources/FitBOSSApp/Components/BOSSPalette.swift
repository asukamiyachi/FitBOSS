import AppKit
import SwiftUI

/// Device-local appearance only; unknown preferences follow macOS.
enum BOSSAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .system }
    var title: String {
        switch self { case .system: "System（システム）"; case .light: "Light（ライト）"; case .dark: "Dark（ダーク）" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

/// Hex values are shared with contrast tests. Colors resolve in each window's appearance.
enum BOSSPalette {
    enum Token: CaseIterable {
        case canvas, surface, elevated, primary, secondary, border, cyan, violet, success, warning, error, actionStart, actionEnd
        func hex(dark: Bool, highContrast: Bool = false) -> UInt32 {
            switch self {
            case .canvas: dark ? 0x0B1324 : 0xF5F8FC
            case .surface: dark ? 0x111B2F : 0xFFFFFF
            case .elevated: dark ? 0x17243C : 0xEAF1FB
            case .primary: dark ? 0xF7FAFF : 0x17223A
            case .secondary: dark ? 0xB8C9E3 : 0x475569
            case .border: dark ? (highContrast ? 0xB8C9E3 : 0x7184A2) : (highContrast ? 0x17223A : 0x63758D)
            case .cyan: dark ? 0x00E5FF : 0x00677A
            case .violet: dark ? 0xCFABFF : 0x6D28D9
            case .success: dark ? 0x68E0A0 : 0x166534
            case .warning: dark ? 0xFBC56A : 0x854D0E
            case .error: dark ? 0xFFADAD : 0xB91C1C
            case .actionStart: dark ? 0x03699A : 0x075985
            case .actionEnd: dark ? 0x6C3FB5 : 0x6D28D9
            }
        }
    }
    static func color(_ token: Token) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let contrast = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            let value = token.hex(dark: dark, highContrast: contrast)
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

struct BOSSInlineNotice: View {
    let message: String
    var symbol = "info.circle.fill"
    var tint: Color = BOSSTheme.blue
    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(BOSSTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint, lineWidth: 1))
            .accessibilityElement(children: .combine)
    }
}
