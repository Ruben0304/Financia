import SwiftUI

/// Full-screen cover shown while the app is locked (or briefly, without the
/// unlock button, while the app sits inactive in the app switcher so the
/// snapshot doesn't expose financial data).
struct AppLockView: View {
    @EnvironmentObject private var appLock: AppLockManager

    /// When `false` the view acts as a plain privacy shield (no unlock button).
    var showsUnlockButton: Bool

    var body: some View {
        ZStack {
            DarkFinanceColors.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(DarkFinanceColors.primaryGradient)
                        .frame(width: 96, height: 96)
                        .shadow(color: DarkFinanceColors.primaryAccent.opacity(0.4), radius: 20, x: 0, y: 10)
                    Image(systemName: appLock.methodIcon)
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("FinancIA")
                        .font(DarkFinanceTypography.title(size: 30))
                        .foregroundColor(DarkFinanceColors.primaryText)
                    Text("Tus finanzas están protegidas")
                        .font(DarkFinanceTypography.body(size: 15))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                }

                Spacer()

                if showsUnlockButton {
                    Button {
                        Task { await appLock.authenticate() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: appLock.methodIcon)
                                .font(.system(size: 18, weight: .semibold))
                            Text("Desbloquear")
                                .font(DarkFinanceTypography.emphasis(size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DarkFinanceColors.primaryGradient)
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}
