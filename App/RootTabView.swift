import SwiftUI

struct RootTabView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                ConnectionSetupView(model: model)
            }
            .tabItem {
                Label("相机", systemImage: "camera")
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
                Label("下载", systemImage: "tray.and.arrow.down")
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
                        .tint(AppTheme.accentStrong)
                    Text(model.workingStatusTitle)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(AppTheme.ink)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.surface, in: Capsule())
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 4)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isWorking)
        .tint(AppTheme.accentStrong)
        .background(AppTheme.canvas.ignoresSafeArea())
        .applyTabBarChrome()
        .alert(item: $model.alertContext) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("确定"))
            )
        }
    }
}

private extension View {
    @ViewBuilder
    func applyTabBarChrome() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(AppTheme.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        #else
        self
        #endif
    }
}
