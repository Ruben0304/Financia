import SwiftUI
import UIKit

enum AuroraColors {
    static let primaryText = Color.adaptive(light: Color(red: 0.10, green: 0.20, blue: 0.36), dark: .white)
    static let secondaryText = Color.adaptive(
        light: Color(red: 0.19, green: 0.34, blue: 0.52).opacity(0.85),
        dark: Color.white.opacity(0.72)
    )
}

struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    colorScheme == .dark
                        ? Color(red: 0.05, green: 0.08, blue: 0.14)
                        : Color(red: 0.96, green: 0.99, blue: 1.0),
                    colorScheme == .dark
                        ? Color(red: 0.10, green: 0.16, blue: 0.26)
                        : Color(red: 0.80, green: 0.90, blue: 1.0),
                    colorScheme == .dark
                        ? Color(red: 0.18, green: 0.11, blue: 0.18)
                        : Color(red: 0.98, green: 0.88, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.9),
                    Color.white.opacity(0)
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 320
            )
            .offset(x: -60, y: -100)

            RadialGradient(
                colors: [
                    colorScheme == .dark
                        ? Color(red: 0.78, green: 0.35, blue: 0.51).opacity(0.24)
                        : Color(red: 0.99, green: 0.86, blue: 0.92).opacity(0.8),
                    Color.white.opacity(0)
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .offset(x: 80, y: 20)

            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color(red: 0.33, green: 0.53, blue: 0.78).opacity(0.22)
                        : Color(red: 0.82, green: 0.93, blue: 1.0).opacity(0.4)
                )
                .blur(radius: 90)
                .frame(width: 320, height: 320)
                .offset(x: -140, y: 200)

            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color(red: 0.74, green: 0.38, blue: 0.57).opacity(0.20)
                        : Color(red: 0.99, green: 0.86, blue: 0.95).opacity(0.45)
                )
                .blur(radius: 70)
                .frame(width: 260, height: 260)
                .offset(x: 160, y: -140)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35))
                .blur(radius: 50)
                .frame(width: 140, height: 140)
                .offset(x: 40, y: -20)
        }
    }
}

// MARK: - Dark Finance Theme Colors
enum DarkFinanceColors {
    // Backgrounds
    static let background = Color.adaptive(light: Color(hex: "F6F8FC"), dark: Color(hex: "0A0A0B"))
    static let cardBackground = Color.adaptive(light: .white, dark: Color(hex: "111113"))
    static let cardBorder = Color.adaptive(light: Color.black.opacity(0.08), dark: Color(hex: "1F1F23"))
    static let inputBackground = Color.adaptive(light: Color(hex: "EFF3F8"), dark: Color(hex: "1A1A1D"))
    static let inputBorder = Color.adaptive(light: Color.black.opacity(0.10), dark: Color(hex: "2A2A2E"))

    // Text Colors
    static let primaryText = Color.adaptive(light: Color(hex: "101828"), dark: Color(hex: "FFFFFF"))
    static let secondaryText = Color.adaptive(light: Color(hex: "475467"), dark: Color(hex: "8B8B90"))
    static let tertiaryText = Color.adaptive(light: Color(hex: "667085"), dark: Color(hex: "6B6B70"))

    // Accent Colors
    static let primaryAccent = Color(hex: "FF5C00")
    static let primaryAccentLight = Color(hex: "FF8A4C")
    static let successGreen = Color(hex: "22C55E")
    static let successGreenDark = Color(hex: "16A34A")
    static let errorRed = Color(hex: "EF4444")
}

// MARK: - Gradients
extension DarkFinanceColors {
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, primaryAccentLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [successGreen, successGreenDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cardBackground, inputBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography
enum DarkFinanceTypography {
    static func monoAmount(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func title(size: CGFloat = 28) -> Font {
        .custom("Georgia", size: size)
    }

    static func toolbarTitle(size: CGFloat = 24) -> Font {
        .custom("Georgia", size: size)
    }

    static func toolbarSubtitle(size: CGFloat = 12, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func sectionTitle(size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func emphasis(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func action(size: CGFloat = 13, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func caption(size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Dark Background View
struct DarkFinanceBackground: View {
    var body: some View {
        DarkFinanceColors.background
            .ignoresSafeArea()
    }
}

// MARK: - Card Modifier
struct DarkFinanceCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DarkFinanceColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func darkFinanceCard(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        modifier(DarkFinanceCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Input Field Style
struct DarkInputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DarkFinanceColors.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DarkFinanceColors.inputBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func darkInputStyle() -> some View {
        modifier(DarkInputField())
    }

    func darkFinanceToolbarTitle(size: CGFloat = 24) -> some View {
        font(DarkFinanceTypography.toolbarTitle(size: size))
    }

    func darkFinanceToolbarSubtitle(size: CGFloat = 12, weight: Font.Weight = .semibold) -> some View {
        font(DarkFinanceTypography.toolbarSubtitle(size: size, weight: weight))
    }

    func darkFinanceSectionTitle(size: CGFloat = 16) -> some View {
        font(DarkFinanceTypography.sectionTitle(size: size))
    }

    func darkFinanceEmphasis(size: CGFloat = 14) -> some View {
        font(DarkFinanceTypography.emphasis(size: size))
    }

    func darkFinanceBody(size: CGFloat = 14, weight: Font.Weight = .regular) -> some View {
        font(DarkFinanceTypography.body(size: size, weight: weight))
    }

    func darkFinanceCaption(size: CGFloat = 12, weight: Font.Weight = .regular) -> some View {
        font(DarkFinanceTypography.caption(size: size, weight: weight))
    }

    func darkFinanceAction(size: CGFloat = 13, weight: Font.Weight = .medium) -> some View {
        font(DarkFinanceTypography.action(size: size, weight: weight))
    }
}

// MARK: - Primary Button Style
struct DarkPrimaryButton: ButtonStyle {
    var color: LinearGradient = DarkFinanceColors.successGradient
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DarkFinanceTypography.emphasis(size: 16))
            .foregroundColor(DarkFinanceColors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color)
            .cornerRadius(14)
            .opacity(isDisabled ? 0.5 : (configuration.isPressed ? 0.8 : 1.0))
    }
}

// MARK: - Helper Extension for Hex Colors
extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AIGlassBackground: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let start = UnitPoint(x: 0.08 + 0.12 * sin(time * 0.45), y: 0.20 + 0.10 * cos(time * 0.35))
            let end = UnitPoint(x: 0.92 - 0.12 * cos(time * 0.40), y: 0.84 - 0.10 * sin(time * 0.30))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "2A2A31").opacity(0.92),
                            Color(hex: "44444C").opacity(0.76),
                            Color(hex: "2B2D32").opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            AngularGradient(
                                colors: colors + [colors.first ?? .white],
                                center: .center,
                                angle: .degrees(time * 28)
                            ),
                            lineWidth: 1.6
                        )
                        .blur(radius: 0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .padding(1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(colors: colors.map { $0.opacity(0.55) }, startPoint: start, endPoint: end)
                        )
                        .blur(radius: 24)
                        .padding(-5)
                )
                .overlay(alignment: .bottom) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colors.map { $0.opacity(0.55) },
                                startPoint: start,
                                endPoint: end
                            )
                        )
                        .frame(height: 16)
                        .blur(radius: 18)
                        .offset(y: 18)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.10))
                        .frame(width: 180, height: 78)
                        .blur(radius: 18)
                        .offset(x: 10, y: 4)
                }
                .shadow(color: colors.first?.opacity(0.22) ?? .clear, radius: 22, x: 0, y: 10)
        }
    }
}
