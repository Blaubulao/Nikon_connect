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
        .background(backgroundStyle, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(foregroundStyle.opacity(0.18), lineWidth: 1)
        )
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
        AppTheme.workflowColor(for: state)
    }

    private var backgroundStyle: Color {
        foregroundStyle.opacity(0.10)
    }
}
