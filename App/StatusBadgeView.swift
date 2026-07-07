import SwiftUI

struct StatusBadgeView: View {
    let state: CameraWorkflowState
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(foregroundStyle)
                .frame(width: 5, height: 5)
                .scaleEffect(isWorkingState && isPulsing ? 1.25 : 1)
                .opacity(isWorkingState && isPulsing ? 0.45 : 1)
                .onAppear {
                    guard isWorkingState else { return }
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }

            Label(state.title, systemImage: state.symbolName)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(foregroundStyle)
        .background(foregroundStyle.opacity(0.08), in: Capsule())
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
}
