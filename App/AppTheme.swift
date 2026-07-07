import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.95, green: 0.72, blue: 0.10)
    static let accentStrong = Color(red: 0.83, green: 0.55, blue: 0.06)
    static let accentSoft = Color(red: 0.99, green: 0.95, blue: 0.86)

    static let ink = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let inkMuted = Color(red: 0.37, green: 0.43, blue: 0.53)
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.97, green: 0.98, blue: 0.99)
    static let border = Color(red: 0.88, green: 0.91, blue: 0.95)

    static let info = Color(red: 0.22, green: 0.43, blue: 0.86)
    static let success = Color(red: 0.18, green: 0.60, blue: 0.35)
    static let warning = Color(red: 0.87, green: 0.49, blue: 0.08)
    static let danger = Color(red: 0.82, green: 0.23, blue: 0.24)
    static let shadow = Color.black.opacity(0.05)

    static func workflowColor(for state: CameraWorkflowState) -> Color {
        switch state {
        case .waitingForWifi:
            return info
        case .connecting, .loadingPhotos, .downloading:
            return warning
        case .connected:
            return success
        case .error:
            return danger
        }
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let systemImage: String
    var accent: Color = AppTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(label)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.inkMuted)
            }

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
