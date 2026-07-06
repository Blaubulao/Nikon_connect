import SwiftUI

struct RootTabView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                ConnectionSetupView(model: model)
            }
            .tabItem {
                Label("连接", systemImage: "wifi")
            }

            NavigationStack {
                PhotoBrowserView(model: model)
            }
            .tabItem {
                Label("照片", systemImage: "photo.on.rectangle")
            }

            NavigationStack {
                DownloadsView(model: model)
            }
            .tabItem {
                Label("下载", systemImage: "arrow.down.circle")
            }

            NavigationStack {
                SettingsView(model: model)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .overlay(alignment: .top) {
            if model.isWorking {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.primary)
                    Text(model.workflowState.title)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isWorking)
        .alert(item: $model.alertContext) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("确定"))
            )
        }
    }
}
