import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.96, green: 0.72, blue: 0.12)
    static let accentStrong = Color(red: 0.76, green: 0.48, blue: 0.04)
    static let accentSoft = Color(red: 1.00, green: 0.96, blue: 0.86)

    static let ink = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let inkMuted = Color(red: 0.43, green: 0.47, blue: 0.54)
    static let canvas = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let surface = Color.white
    static let surfaceElevated = Color.white.opacity(0.96)
    static let surfaceMuted = Color(red: 0.95, green: 0.95, blue: 0.94)
    static let controlBackground = Color(red: 0.92, green: 0.92, blue: 0.91)
    static let subtleFill = Color.black.opacity(0.035)
    static let border = Color.black.opacity(0.07)
    static let separator = Color.black.opacity(0.08)

    static let info = Color(red: 0.20, green: 0.39, blue: 0.78)
    static let success = Color(red: 0.15, green: 0.55, blue: 0.32)
    static let warning = Color(red: 0.78, green: 0.43, blue: 0.06)
    static let danger = Color(red: 0.78, green: 0.20, blue: 0.22)
    static let shadow = Color.black.opacity(0.025)

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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(accent.opacity(0.85))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(label)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
