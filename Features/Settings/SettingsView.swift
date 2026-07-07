import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                preferencesSection
                supportSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var preferencesSection: some View {
        CustomCard(title: "偏好设置") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("自动导出到系统相册")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("开启后，下载完成会继续尝试写入 iOS 系统相册；关闭时仅保留在应用本地。")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.inkMuted)
                }

                Toggle(
                    "允许自动导出",
                    isOn: Binding(
                        get: { model.autoExportToPhotoLibrary },
                        set: { model.setAutoExportToPhotoLibrary($0) }
                    )
                )
                .font(.system(.body, design: .rounded).weight(.semibold))
                .tint(AppTheme.accentStrong)
            }
        }
    }

    private var supportSection: some View {
        CustomCard(title: "高级与支持") {
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup("连接默认值") {
                    VStack(alignment: .leading, spacing: 12) {
                        GridRowItem(label: "模式", value: model.transportMode.title, systemImage: "network")
                        GridRowItem(
                            label: "端口",
                            value: model.portInput.isEmpty ? String(model.transportMode.defaultPort) : model.portInput,
                            systemImage: "number.square"
                        )
                        GridRowItem(
                            label: "地址",
                            value: model.hostInput.isEmpty ? "未设置" : model.hostInput,
                            systemImage: "ipad.and.iphone"
                        )
                    }
                    .padding(.top, 12)
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .tint(AppTheme.ink)

                if !model.activityLog.isEmpty {
                    Divider()

                    DisclosureGroup("调试记录") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.activityLog.prefix(12)) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(logColor(for: entry.message))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.message)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(textColor(for: entry.message))
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text(Formatters.logTime(entry.timestamp))
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(AppTheme.inkMuted.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .tint(AppTheme.ink)
                }

                Divider()

                DisclosureGroup("关于此版本") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nikon Connect MVP v0.1.0")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Text("当前版本支持演示模式与 Nikon 手动 Wi-Fi 连接，重点解决照片浏览与下载这条主链路。")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .tint(AppTheme.ink)
            }
        }
    }

    private func logColor(for msg: String) -> Color {
        if msg.contains("失败") || msg.contains("错误") || msg.contains("Error") {
            return AppTheme.danger
        } else if msg.contains("诊断") {
            return AppTheme.info
        } else if msg.contains("成功") || msg.contains("已连接") {
            return AppTheme.success
        } else {
            return AppTheme.warning
        }
    }

    private func textColor(for msg: String) -> Color {
        if msg.contains("失败") || msg.contains("错误") || msg.contains("Error") {
            return AppTheme.danger
        } else if msg.contains("诊断") {
            return AppTheme.info
        } else if msg.contains("成功") || msg.contains("已连接") {
            return AppTheme.success
        } else {
            return AppTheme.ink
        }
    }
}
