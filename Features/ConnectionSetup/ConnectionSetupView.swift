import SwiftUI

struct ConnectionSetupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                workflowSection
                connectionSection

                if let session = model.activeSession {
                    sessionSection(session)
                }

                if !model.activityLog.isEmpty {
                    recentEventsSection
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("相机")
    }

    private var statusColor: Color {
        switch model.workflowState {
        case .connected:
            return Color(red: 0.13, green: 0.75, blue: 0.42)
        case .error:
            return Color(red: 0.92, green: 0.26, blue: 0.35)
        case .waitingForWifi:
            return Color(red: 0.20, green: 0.50, blue: 0.98)
        default:
            return Color(red: 0.98, green: 0.65, blue: 0.11)
        }
    }

    private var workflowSection: some View {
        CustomCard(title: "工作流程") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前状态")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    StatusBadgeView(state: model.workflowState)
                }
                
                Spacer()
                
                Image(systemName: model.workflowState.symbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(statusColor)
                    .frame(width: 44, height: 44)
                    .background(statusColor.opacity(0.12), in: Circle())
            }
            
            Divider()
            
            Text(model.lastSummary)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("提示：先在 iPhone 系统设置里连上尼康相机的 Wi-Fi 热点，然后再点击下方连接。")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var connectionSection: some View {
        CustomCard(title: "相机连接") {
            VStack(alignment: .leading, spacing: 10) {
                Text("选择模式")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(CameraTransportMode.allCases) { mode in
                        let isSelected = model.transportMode == mode
                        Button {
                            model.setTransportMode(mode)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isSelected ? .black : .primary)
                                
                                Text(mode == .demo ? "内置演示" : "PTP/IP 协议")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(isSelected ? .black.opacity(0.7) : .secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(isSelected ? Color(red: 0.99, green: 0.85, blue: 0.05) : Color(.systemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Text(model.transportMode.detail)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
            
            Divider()
            
            HStack {
                Label(model.transportMode == .demo ? "当前目标" : "默认目标", systemImage: "network")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(model.connectionTargetDescription)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            if model.transportMode == .experimentalNikon {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("当前版本使用尼康常用热点地址，免去手填繁琐。")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                Task {
                    await model.connect()
                }
            } label: {
                HStack {
                    Spacer()
                    Label(
                        model.transportMode == .demo ? "载入演示会话" : "连接相机",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(model.canAttemptConnection && !model.isWorking ? .black : .secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    model.canAttemptConnection && !model.isWorking
                    ? LinearGradient(colors: [Color(red: 0.99, green: 0.85, blue: 0.05), Color(red: 0.98, green: 0.70, blue: 0.03)], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color(.systemFill)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: model.canAttemptConnection && !model.isWorking ? Color(red: 0.99, green: 0.85, blue: 0.05).opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
            }
            .disabled(!model.canAttemptConnection || model.isWorking)
            .buttonStyle(.plain)
            
            if model.activeSession != nil {
                Button {
                    model.disconnect()
                } label: {
                    HStack {
                        Spacer()
                        Label("清除会话", systemImage: "xmark.circle")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sessionSection(_ session: CameraSession) -> some View {
        CustomCard(title: "当前会话") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(red: 0.99, green: 0.85, blue: 0.05))
                        .frame(width: 48, height: 48)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.cameraName)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                        
                        Text("\(session.connectedHost):\(String(session.port))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 4)
                
                Divider()
                
                GridRowItem(label: "连接时间", value: Formatters.shortDate(session.connectedAt), systemImage: "clock")
                
                GridRowItem(
                    label: "相机能力",
                    value: session.capabilities.map(\.title).sorted().joined(separator: "、"),
                    systemImage: "wand.and.stars"
                )
                
                if session.capabilities.contains(.listAssets) {
                    Divider()
                    
                    Button {
                        Task {
                            await model.refreshPhotos()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("重新读取首批照片", systemImage: "arrow.clockwise")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(!model.canRefreshPhotos)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentEventsSection: some View {
        CustomCard(title: "最近事件") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.activityLog.prefix(8)) { entry in
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

struct CustomCard<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct GridRowItem: View {
    let label: String
    let value: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
            
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
