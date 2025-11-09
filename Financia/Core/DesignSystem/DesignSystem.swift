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
