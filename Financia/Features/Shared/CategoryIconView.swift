import SwiftUI

/// Renders a category icon that can be either an SF Symbol name or an emoji/text string.
///
/// We detect which kind by attempting `UIImage(systemName:)` — all valid SF Symbol
/// names are ASCII (letters, dots, numbers), so any emoji string or multi-byte text
/// will fail and be rendered as a `Text` instead.
struct CategoryIconView: View {
    let icon: String
    let color: Color
    var size: CGFloat = 15

    var body: some View {
        if UIImage(systemName: icon) != nil {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(color)
        } else {
            Text(icon.isEmpty ? "🏷️" : icon)
                .font(.system(size: size))
        }
    }
}
