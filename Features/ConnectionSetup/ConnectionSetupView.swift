import SwiftUI

struct ConnectionSetupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                heroSection

                if let session = model.activeSession {
                    readySection(session)
                }

                advancedSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("相机")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        CustomCard(title: "快速开始") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(heroTitle)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        Text(heroDescription)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    StatusBadgeView(state: model.workflowState)
                }

                HStack(spacing: 10) {
                    Image(systemName: model.transportMode == .demo ? "sparkles" : "wifi")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.accentStrong)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(connectionHint)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(AppTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("连接方式")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.inkMuted)

                    HStack(spacing: 10) {
                        ForEach(CameraTransportMode.allCases) { mode in
                            transportModeButton(for: mode)
                        }
                    }
                }

                Button {
                    Task {
                        await model.connect()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label(primaryActionTitle, systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(model.canAttemptConnection && !model.isWorking ? AppTheme.ink : AppTheme.inkMuted)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(model.canAttemptConnection && !model.isWorking ? AppTheme.accent : AppTheme.surfaceMuted)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!model.canAttemptConnection || model.isWorking)

                if model.activeSession != nil {
                    Button {
                        model.disconnect()
                    } label: {
                        HStack {
                            Spacer()
                            Text("断开并清除当前会话")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.danger)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(AppTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func readySection(_ session: CameraSession) -> some View {
        CustomCard(title: "连接已就绪") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
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
                    Button {
                        Task {
                            await model.refreshPhotos()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label(model.photoAssets.isEmpty ? "读取首批照片" : "重新读取照片", systemImage: "arrow.clockwise")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canRefreshPhotos)
                }
            }
        }
    }

    private var advancedSection: some View {
        CustomCard(title: "辅助信息") {
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup("连接详情") {
                    VStack(alignment: .leading, spacing: 12) {
                        GridRowItem(label: "模式", value: model.transportMode.title, systemImage: "switch.2")
                        GridRowItem(label: "目标", value: model.connectionTargetDescription, systemImage: "network")

                        if let session = model.activeSession {
                            GridRowItem(label: "已连接到", value: "\(session.connectedHost):\(String(session.port))", systemImage: "antenna.radiowaves.left.and.right")
                            GridRowItem(label: "能力", value: capabilitySummary(for: session), systemImage: "checklist")
                        }

                        Text(model.lastSummary)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .tint(AppTheme.ink)

                if !model.activityLog.isEmpty {
                    Divider()

                    DisclosureGroup("最近记录") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.activityLog.prefix(6)) { entry in
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
        let isSelected = model.transportMode == mode

        return Button {
            model.setTransportMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(mode == .demo ? "演示" : "真实相机")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.ink)

                Text(mode == .demo ? "用样例数据快速体验" : "连接 Nikon Wi-Fi 热点")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(isSelected ? AppTheme.inkMuted : AppTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppTheme.accentSoft : AppTheme.surfaceMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppTheme.accentStrong.opacity(0.4) : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var heroTitle: String {
        if let session = model.activeSession {
            return "\(session.cameraName) 已连接"
        }

        switch model.workflowState {
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
        switch model.workflowState {
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
        switch model.transportMode {
        case .demo:
            return "演示模式会直接载入样例内容，适合先看界面和流程。"
        case .experimentalNikon:
            return "真实连接时，不需要手动填 IP，当前版本会使用尼康常见热点地址自动尝试连接。"
        }
    }

    private var primaryActionTitle: String {
        model.transportMode == .demo ? "载入演示内容" : "连接相机"
    }

    private var photoStatusSummary: String {
        if model.photoAssets.isEmpty {
            return model.canRefreshPhotos ? "待读取" : "未就绪"
        }

        return model.hasMorePhotos ? "已载入 \(model.photoAssets.count)+" : "已载入 \(model.photoAssets.count)"
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

struct CustomCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.inkMuted)
                    .padding(.horizontal, 2)
            }

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 4)
        }
    }
}

struct GridRowItem: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.inkMuted)
                .frame(width: 18, height: 18)

            Text(label)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.inkMuted)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct DownloadProgressDetails: View {
    let progress: ActiveDownloadProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在下载")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.inkMuted)

                    Text(progress.fileName)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                }

                Spacer()

                Text(progress.percentageText)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.accentStrong)
            }

            ProgressView(value: progress.fractionCompleted)
                .tint(AppTheme.accentStrong)

            HStack {
                Text("第 \(progress.currentItemNumber) / \(progress.totalItemCount) 项")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.inkMuted)

                Spacer()

                Text("\(Formatters.fileSize(progress.bytesTransferred)) / \(Formatters.fileSize(progress.totalBytes))")
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(AppTheme.inkMuted)
            }
        }
    }
}
