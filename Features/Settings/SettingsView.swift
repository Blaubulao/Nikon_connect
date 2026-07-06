import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                preferencesSection
                configSection
                
                if !model.activityLog.isEmpty {
                    debugLogsSection
                }
                
                buildNotesSection
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("设置")
    }

    private var preferencesSection: some View {
        CustomCard(title: "偏好设置") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "自动导出到系统相册",
                    isOn: Binding(
                        get: { model.autoExportToPhotoLibrary },
                        set: { model.setAutoExportToPhotoLibrary($0) }
                    )
                )
                .font(.system(.body, design: .rounded).weight(.semibold))
                .tint(Color(red: 0.99, green: 0.85, blue: 0.05))
                
                Text("下载会先保存到 App 沙盒本地目录；如果开启这个选项，随后会尝试写入 iOS 系统相册。")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var configSection: some View {
        CustomCard(title: "默认连接配置") {
            GridRowItem(label: "模式", value: model.transportMode.title, systemImage: "network")
            
            Divider()
            
            GridRowItem(
                label: "端口",
                value: model.portInput.isEmpty ? String(model.transportMode.defaultPort) : model.portInput,
                systemImage: "number.square"
            )
            
            Divider()
            
            GridRowItem(
                label: "地址",
                value: model.hostInput.isEmpty ? "未设置" : model.hostInput,
                systemImage: "ipad.and.iphone"
            )
        }
    }

    private var debugLogsSection: some View {
        CustomCard(title: "系统调试日志") {
            VStack(alignment: .leading, spacing: 10) {
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
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text(Formatters.logTime(entry.timestamp))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var buildNotesSection: some View {
        CustomCard(title: "关于与说明") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.99, green: 0.85, blue: 0.05))
                    
                    Text("当前版本 MVP v0.1.0")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                }
                
                Text("当前工程支持演示模式及尼康手动 Wi-Fi 热点连接。底层通过原生 TCP 套接字握手并抓取 PTP/IP 图像数据，确保传输性能与稳定。")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func logColor(for msg: String) -> Color {
        if msg.contains("失败") || msg.contains("错误") || msg.contains("Error") {
            return Color.red
        } else if msg.contains("诊断") {
            return Color.blue
        } else if msg.contains("成功") || msg.contains("已连接") {
            return Color.green
        } else {
            return Color.orange
        }
    }

    private func textColor(for msg: String) -> Color {
        if msg.contains("失败") || msg.contains("错误") || msg.contains("Error") {
            return Color(red: 0.80, green: 0.15, blue: 0.20)
        } else if msg.contains("诊断") {
            return Color(red: 0.10, green: 0.45, blue: 0.82)
        } else if msg.contains("成功") || msg.contains("已连接") {
            return Color(red: 0.10, green: 0.62, blue: 0.35)
        } else {
            return Color.primary
        }
    }
}
