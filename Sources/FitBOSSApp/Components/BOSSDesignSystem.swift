import SwiftUI

/// Shared presentation-only styling. No network calls, exercise logic, or persisted state.
enum BOSSTheme {
    static let canvas = BOSSPalette.color(.canvas)
    static let surface = BOSSPalette.color(.surface)
    static let elevated = BOSSPalette.color(.elevated)
    static let primary = BOSSPalette.color(.primary)
    static let border = BOSSPalette.color(.border)
    static let blue = BOSSPalette.color(.cyan)
    static let violet = BOSSPalette.color(.violet)
    static let mint = BOSSPalette.color(.success)
    static let warning = BOSSPalette.color(.warning)
    static let error = BOSSPalette.color(.error)
    static let muted = BOSSPalette.color(.secondary)
    static let action = LinearGradient(
        colors: [BOSSPalette.color(.actionStart), BOSSPalette.color(.actionEnd)],
        startPoint: .leading, endPoint: .trailing
    )
}

/// A testable sizing rule for the 820×540 macOS window and smaller detail panes.
enum BOSSLayoutPolicy {
    static let compactTrainingBreakpoint: CGFloat = 770

    static func compactTraining(detailWidth: CGFloat) -> Bool {
        detailWidth < compactTrainingBreakpoint
    }

    static func compactCameraHeight(windowHeight: CGFloat) -> CGFloat {
        max(220, min(320, windowHeight * 0.45))
    }
}

private struct BOSSBackground: View {
    var body: some View {
        BOSSTheme.canvas
        .ignoresSafeArea()
    }
}

struct BOSSPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        heading
                        Spacer(minLength: 8)
                        Text("FITBOSS  //")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(BOSSTheme.blue)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    heading
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                content
            }
            .frame(maxWidth: 1320, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(BOSSBackground())
        .foregroundStyle(BOSSTheme.primary)
        .navigationTitle(title)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(BOSSTheme.primary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(BOSSTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BOSSPanel<Content: View>: View {
    var title: String? = nil
    var symbol: String = "circle.grid.2x2"
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Label(title, systemImage: symbol)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BOSSTheme.primary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(19)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BOSSTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            BOSSTheme.border,
                            lineWidth: 1
                        )
                }
        }
    }
}

struct BOSSPill: View {
    let text: String
    let symbol: String
    var tint: Color = BOSSTheme.blue

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(BOSSTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(tint, lineWidth: 1))
    }
}

struct BOSSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 14)
            .background(BOSSTheme.action, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).fill(.black.opacity(configuration.isPressed ? 0.15 : 0)).allowsHitTesting(false))
            .saturation(isEnabled ? 1 : 0)
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(isFocused ? BOSSTheme.blue : BOSSTheme.border, lineWidth: isFocused ? 3 : hovering && isEnabled ? 2 : 1))
            .onHover { hovering = $0 }
    }
}

struct BOSSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? BOSSTheme.primary : BOSSTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 11)
            .background(configuration.isPressed ? BOSSTheme.elevated : BOSSTheme.surface,
                        in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isEnabled ? BOSSTheme.primary : BOSSTheme.muted)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isFocused ? BOSSTheme.blue : BOSSTheme.border, lineWidth: isFocused ? 3 : hovering && isEnabled ? 2 : 1))
            .onHover { hovering = $0 }
    }
}

struct BOSSStatCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(BOSSTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .foregroundStyle(BOSSTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 29, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .padding(17)
        .background {
            RoundedRectangle(cornerRadius: 17)
                .fill(BOSSTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(BOSSTheme.border, lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }
}