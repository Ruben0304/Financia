import SwiftUI

enum AuroraColors {
    static let primaryText = Color(red: 0.10, green: 0.20, blue: 0.36)
    static let secondaryText = Color(red: 0.19, green: 0.34, blue: 0.52).opacity(0.85)
}

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.99, blue: 1.0),
                    Color(red: 0.80, green: 0.90, blue: 1.0),
                    Color(red: 0.98, green: 0.88, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0)],
                center: .topLeading,
                startRadius: 40,
                endRadius: 320
            )
            .offset(x: -60, y: -100)

            RadialGradient(
                colors: [Color(red: 0.99, green: 0.86, blue: 0.92).opacity(0.8), Color.white.opacity(0)],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .offset(x: 80, y: 20)

            Circle()
                .fill(Color(red: 0.82, green: 0.93, blue: 1.0).opacity(0.4))
                .blur(radius: 90)
                .frame(width: 320, height: 320)
                .offset(x: -140, y: 200)

            Circle()
                .fill(Color(red: 0.99, green: 0.86, blue: 0.95).opacity(0.45))
                .blur(radius: 70)
                .frame(width: 260, height: 260)
                .offset(x: 160, y: -140)

            Circle()
                .fill(Color.white.opacity(0.35))
                .blur(radius: 50)
                .frame(width: 140, height: 140)
                .offset(x: 40, y: -20)
        }
    }
}

// MARK: - Dark Finance Theme Colors
enum DarkFinanceColors {
    // Backgrounds
    static let background = Color(hex: "0A0A0B")
    static let cardBackground = Color(hex: "111113")
    static let cardBorder = Color(hex: "1F1F23")
    static let inputBackground = Color(hex: "1A1A1D")
    static let inputBorder = Color(hex: "2A2A2E")

    // Text Colors
    static let primaryText = Color(hex: "FFFFFF")
    static let secondaryText = Color(hex: "8B8B90")
    static let tertiaryText = Color(hex: "6B6B70")

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
            colors: [Color(hex: "111113"), Color(hex: "1A1A1D")],
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
        .custom("Instrument Serif", size: size)
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
}

// MARK: - Primary Button Style
struct DarkPrimaryButton: ButtonStyle {
    var color: LinearGradient = DarkFinanceColors.successGradient
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
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
