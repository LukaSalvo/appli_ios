import SwiftUI
import UIKit

// MARK: - Dynamic color helper

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

private extension Color {
    /// A color that resolves differently in light and dark, keyed off the
    /// effective interface style — respects `.preferredColorScheme` overrides.
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

// MARK: - Palette
// "Néo-banque épurée" — near-black + a single emerald signature accent that
// glows in the dark and settles into a deeper, AA-safe emerald in daylight.

extension Color {
    // Backgrounds & surfaces
    static let appBackground = Color(light: 0xF5F6F5, dark: 0x0A0C0D)
    static let appSurface = Color(light: 0xFFFFFF, dark: 0x15181A)
    static let appSurfaceRaised = Color(light: 0xFFFFFF, dark: 0x1B2022)
    static let appHairline = Color(light: 0x0B0D0E, dark: 0xF5F6F5, lightAlpha: 0.08, darkAlpha: 0.12)
    static let appTrack = Color(light: 0x0B0D0E, dark: 0xF5F6F5, lightAlpha: 0.07, darkAlpha: 0.10)

    // Text
    static let appTextPrimary = Color(light: 0x0B0D0E, dark: 0xF5F6F5)
    static let appTextSecondary = Color(light: 0x0B0D0E, dark: 0xF5F6F5, lightAlpha: 0.55, darkAlpha: 0.58)

    // Brand accents
    /// Primary signature accent — money in, CTAs, progress.
    static let appAccent = Color(light: 0x0EA672, dark: 0x1BE8A4)
    static let moneyGood = Color(light: 0x0EA672, dark: 0x1BE8A4)
    /// Secondary accent — "live" status, tickets restau, highlights.
    static let gold = Color(light: 0xB4770A, dark: 0xFFC24D)
    static let goldInk = Color(light: 0x8A5C08, dark: 0xFFCF70)
    /// Money leaving the account (fixed expenses) — cool slate, not alarming.
    static let moneyOut = Color(light: 0x5468C4, dark: 0x93A8FF)
    /// Over-budget / destructive.
    static let moneyDanger = Color(light: 0xD93636, dark: 0xFF6B6B)
}

// MARK: - Appearance mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Système"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Haptics

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Card

/// A glass-like tile used across the app for a consistent look.
/// `hero` gives it a raised surface + an accent-glow border/shadow for the
/// main figures — the near-black surfaces make the emerald accent glow.
struct Card<Content: View>: View {
    var hero: Bool = false
    var content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(hero: Bool = false, @ViewBuilder content: () -> Content) {
        self.hero = hero
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(hero ? Color.appSurfaceRaised : Color.appSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        hero ? Color.appAccent.opacity(colorScheme == .dark ? 0.35 : 0.16) : Color.appHairline,
                        lineWidth: hero ? 1.5 : 1
                    )
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: hero ? 10 : 4)
    }

    private var shadowColor: Color {
        if colorScheme == .dark {
            return hero ? Color.appAccent.opacity(0.20) : .clear
        }
        return Color.black.opacity(hero ? 0.08 : 0.05)
    }

    private var shadowRadius: CGFloat {
        colorScheme == .dark ? (hero ? 26 : 0) : (hero ? 16 : 8)
    }
}

// MARK: - Signature elements

/// The app's one recurring flourish: a big, glanceable money/time figure that
/// glows with the accent color — brighter in dark mode, subtler in daylight.
struct HeroAmountText: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: String
    var color: Color = .appAccent
    var size: CGFloat = 44

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .shadow(color: color.opacity(colorScheme == .dark ? 0.55 : 0.16),
                    radius: colorScheme == .dark ? 20 : 10)
            .contentTransition(.numericText())
    }
}

/// A softly pulsing dot for "live" states (an active session, "in progress").
struct PulsingDot: View {
    var color: Color = .gold
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 2)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 2.4 : 1)
                .opacity(animate ? 0 : 0.7)
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

extension Text {
    /// Small tracked, uppercase caption used for card eyebrows.
    func eyebrow(_ color: Color = .appTextSecondary) -> Text {
        self
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1.1)
            .foregroundColor(color)
    }
}
