import SwiftUI

enum DaymarkTheme {
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let muted = Color.secondary
    static let coral = Color(red: 0.95, green: 0.40, blue: 0.31)
    static let amber = Color(red: 0.98, green: 0.67, blue: 0.25)
    static let mint = Color(red: 0.23, green: 0.70, blue: 0.58)
    static let indigo = Color(red: 0.35, green: 0.39, blue: 0.78)
}

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07))
            }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(DaymarkTheme.coral)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
