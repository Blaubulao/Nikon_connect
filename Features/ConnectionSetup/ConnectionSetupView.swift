import SwiftUI

struct ConnectionSetupView: View {
    let workflowState: CameraWorkflowState
    let transportMode: CameraTransportMode
    let activeSession: CameraSession?
    let canAttemptConnection: Bool
    let isWorking: Bool
    let canRefreshPhotos: Bool
    let photoCount: Int
    let hasMorePhotos: Bool
    let connectionTargetDescription: String
    let lastSummary: String
    let activityLog: [LogEntry]
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onRefreshPhotos: () -> Void
    let onSelectTransportMode: (CameraTransportMode) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                heroSection

                if let activeSession {
                    readySection(activeSession)
                }

                advancedSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("相机")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        CustomCard(title: "快速开始") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(heroTitle)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Spacer(minLength: 8)

                        StatusBadgeView(state: workflowState)
                    }

                    Text(heroDescription)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(connectionHint, systemImage: transportMode == .demo ? "sparkles" : "wifi")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(AppTheme.inkMuted)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("连接方式")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.inkMuted)

                    HStack(spacing: 6) {
                        ForEach(CameraTransportMode.allCases) { mode in
                            transportModeButton(for: mode)
                        }
                    }
                }

                Button(action: onConnect) {
                    HStack {
                        Spacer()
                        Label(primaryActionTitle, systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(canAttemptConnection && !isWorking ? AppTheme.ink : AppTheme.inkMuted)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canAttemptConnection && !isWorking ? AppTheme.accent : AppTheme.surfaceMuted)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canAttemptConnection || isWorking)

                if activeSession != nil {
                    Button(action: onDisconnect) {
                        HStack {
                            Spacer()
                            Text("断开并清除当前会话")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.danger)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func readySection(_ session: CameraSession) -> some View {
        CustomCard(title: "连接已就绪") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accentStrong)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.accentSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.cameraName)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Text("可以直接前往“照片”浏览与下载。")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.inkMuted)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    MetricTile(
                        label: "连接时间",
                        value: Formatters.shortDate(session.connectedAt),
                        systemImage: "clock",
                        accent: AppTheme.info
                    )

                    MetricTile(
                        label: "照片状态",
                        value: photoStatusSummary,
                        systemImage: "photo.on.rectangle",
                        accent: AppTheme.accentStrong
                    )
                }

                if session.capabilities.contains(.listAssets) {
                    Button(action: onRefreshPhotos) {
                        HStack {
                            Spacer()
                            Label(photoCount == 0 ? "读取首批照片" : "重新读取照片", systemImage: "arrow.clockwise")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRefreshPhotos)
                }
            }
        }
    }

    private var advancedSection: some View {
        CustomCard(title: "辅助信息") {
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup("连接详情") {
                    VStack(alignment: .leading, spacing: 12) {
                        GridRowItem(label: "模式", value: transportMode.title, systemImage: "switch.2")
                        GridRowItem(label: "目标", value: connectionTargetDescription, systemImage: "network")

                        if let activeSession {
                            GridRowItem(label: "已连接到", value: "\(activeSession.connectedHost):\(String(activeSession.port))", systemImage: "antenna.radiowaves.left.and.right")
                            GridRowItem(label: "能力", value: capabilitySummary(for: activeSession), systemImage: "checklist")
                        }

                        Text(lastSummary)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .tint(AppTheme.ink)

                if !activityLog.isEmpty {
                    Divider()

                    DisclosureGroup("最近记录") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(activityLog.prefix(6)) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(logColor(for: entry.message))
                                        .frame(width: 7, height: 7)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.message)
                                            .font(.system(.footnote, design: .monospaced))
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
            }
        }
    }

    private func transportModeButton(for mode: CameraTransportMode) -> some View {
        let isSelected = transportMode == mode

        return Button {
            onSelectTransportMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode == .demo ? "演示" : "真实相机")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(mode == .demo ? "样例数据" : "Nikon Wi-Fi")
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppTheme.accentSoft.opacity(0.8) : AppTheme.subtleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accentStrong.opacity(0.25) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var heroTitle: String {
        if let activeSession {
            return "\(activeSession.cameraName) 已连接"
        }

        switch workflowState {
        case .waitingForWifi:
            return "准备连接你的 Nikon 相机"
        case .connecting:
            return "正在建立连接"
        case .loadingPhotos:
            return "正在读取相册"
        case .downloading:
            return "正在传输文件"
        case .error:
            return "连接需要重新处理"
        case .connected:
            return "连接已建立"
        }
    }

    private var heroDescription: String {
        switch workflowState {
        case .waitingForWifi:
            return "把注意力放在一件事上: 先连上相机热点，再回来点一次连接。其余参数会自动带入。"
        case .connecting:
            return "应用正在验证相机连通性并准备会话，保持在当前页面即可。"
        case .connected:
            return "会话已经准备好。接下来直接去“照片”页浏览缩略图，按需要批量下载。"
        case .loadingPhotos:
            return "正在读取相机中的首批内容。读取完成后，照片页会立即可用。"
        case .downloading:
            return "下载会保持在前台继续执行。你可以切换到照片或下载页查看进度。"
        case .error:
            return "当前步骤没有完成。通常重新确认 Wi-Fi 后再次连接，就能继续。"
        }
    }

    private var connectionHint: String {
        switch transportMode {
        case .demo:
            return "演示模式会直接载入样例内容，适合先看界面和流程。"
        case .experimentalNikon:
            return "真实连接时，不需要手动填 IP，当前版本会使用尼康常见热点地址自动尝试连接。"
        }
    }

    private var primaryActionTitle: String {
        transportMode == .demo ? "载入演示内容" : "连接相机"
    }

    private var photoStatusSummary: String {
        if photoCount == 0 {
            return canRefreshPhotos ? "待读取" : "未就绪"
        }

        return hasMorePhotos ? "已载入 \(photoCount)+" : "已载入 \(photoCount)"
    }

    private func capabilitySummary(for session: CameraSession) -> String {
        session.capabilities
            .map(\.title)
            .sorted()
            .joined(separator: "、")
    }

    private func logColor(for message: String) -> Color {
        if message.contains("失败") || message.contains("错误") || message.contains("Error") {
            return AppTheme.danger
        }

        if message.contains("成功") || message.contains("已连接") {
            return AppTheme.success
        }

        if message.contains("诊断") {
            return AppTheme.info
        }

        return AppTheme.warning
    }

    private func textColor(for message: String) -> Color {
        if message.contains("失败") || message.contains("错误") || message.contains("Error") {
            return AppTheme.danger
        }

        if message.contains("成功") || message.contains("已连接") {
            return AppTheme.success
        }

        if message.contains("诊断") {
            return AppTheme.info
        }

        return AppTheme.ink
    }
}
