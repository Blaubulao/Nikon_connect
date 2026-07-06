import SwiftUI

struct StatusBadgeView: View {
    let state: CameraWorkflowState
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            if isWorkingState {
                Circle()
                    .fill(foregroundStyle)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isPulsing ? 1.4 : 0.8)
                    .opacity(isPulsing ? 0.3 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            } else {
                Circle()
                    .fill(foregroundStyle)
                    .frame(width: 6, height: 6)
            }
            
            Label(state.title, systemImage: state.symbolName)
                .font(.system(.caption, design: .rounded).weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(foregroundStyle)
        .background(
            Capsule()
                .fill(backgroundStyle)
        )
        .overlay(
            Capsule()
                .strokeBorder(foregroundStyle.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: foregroundStyle.opacity(0.1), radius: 3, x: 0, y: 1.5)
    }

    private var isWorkingState: Bool {
        switch state {
        case .connecting, .loadingPhotos, .downloading:
            return true
        default:
            return false
        }
    }

    private var foregroundStyle: Color {
        switch state {
        case .connected:
            return Color(red: 0.13, green: 0.75, blue: 0.42) // Emerald Green
        case .error:
            return Color(red: 0.92, green: 0.26, blue: 0.35) // Crimson Red
        case .waitingForWifi:
            return Color(red: 0.20, green: 0.50, blue: 0.98) // Tech Blue
        default:
            return Color(red: 0.98, green: 0.65, blue: 0.11) // Amber Orange
        }
    }

    private var backgroundStyle: Color {
        foregroundStyle.opacity(0.08)
    }
}
