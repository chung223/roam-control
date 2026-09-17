import SwiftUI

struct ConnectionBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(SproutTheme.font(.caption, weight: .semibold))
                .foregroundStyle(SproutTheme.text)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(SproutTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: SproutTheme.mapControlDiameter)
        .glassEffect(.regular.interactive(), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Connection status: \(label)")
    }

    private var label: String {
        switch state {
        case .notConfigured: .appText("Set up iPhone")
        case .ready: .appText("Ready")
        case .connecting: .appText("Connecting…")
        case .active: .appText("Session active")
        case .failed: .appText("Connection error")
        }
    }

    private var color: Color {
        switch state {
        case .notConfigured: SproutTheme.accent
        case .ready: SproutTheme.positive
        case .connecting: SproutTheme.primary
        case .active: SproutTheme.primary
        case .failed: SproutTheme.accent
        }
    }
}
