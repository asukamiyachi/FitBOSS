import SwiftUI

/// Shared presentation-only styling. No network calls, exercise logic, or persisted state.
enum BOSSTheme {
    static let canvas = Color(red: 0.035, green: 0.052, blue: 0.105)
    static let surface = Color(red: 0.085, green: 0.105, blue: 0.190)
    static let blue = Color(red: 0.16, green: 0.73, blue: 1.00)
    static let violet = Color(red: 0.68, green: 0.30, blue: 1.00)
    static let mint = Color(red: 0.32, green: 0.91, blue: 0.70)
    static let muted = Color(red: 0.70, green: 0.75, blue: 0.86)

    static let action = LinearGradient(
        colors: [blue, Color(red: 0.31, green: 0.39, blue: 0.98), violet],
        startPoint: .leading, endPoint: .trailing
    )
}

private struct BOSSBackground: View {
    var body: some View {
        ZStack {
            BOSSTheme.canvas
            RadialGradient(
                colors: [BOSSTheme.violet.opacity(0.28), .clear],
                center: .topTrailing, startRadius: 25, endRadius: 610
            )
            RadialGradient(
                colors: [BOSSTheme.blue.opacity(0.16), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: 510
            )
        }
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
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(BOSSTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Text("FITBOSS  //")
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(BOSSTheme.blue)
                }
                content
            }
            .frame(maxWidth: 1320, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(BOSSBackground())
        .preferredColorScheme(.dark)
        .navigationTitle(title)
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
                    .foregroundStyle(.white)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(19)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BOSSTheme.surface.opacity(0.87))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.20), BOSSTheme.violet.opacity(0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
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
            .background(tint.opacity(0.13), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.38), lineWidth: 1))
    }
}

struct BOSSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 14)
            .background(BOSSTheme.action, in: RoundedRectangle(cornerRadius: 13))
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.42)
            .shadow(color: BOSSTheme.violet.opacity(0.22), radius: 12, y: 4)
    }
}

struct BOSSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 11)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.09),
                        in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.42)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.17)))
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
                .foregroundStyle(.white)
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
                .fill(accent.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 17)
                    .strokeBorder(accent.opacity(0.46), lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }
}