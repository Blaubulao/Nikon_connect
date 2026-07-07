import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DownloadsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                overviewSection

                if let progress = model.activeDownloadProgress {
                    activeDownloadSection(progress)
                }

                recordsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("下载")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var exportedCount: Int {
        model.downloads.filter(\.exportedToPhotoLibrary).count
    }

    private var overviewSection: some View {
        CustomCard(title: "下载库") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("下载结果会先保存到应用本地，是否同步到系统相册由偏好设置控制。")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    MetricTile(
                        label: "记录数",
                        value: "\(model.downloads.count)",
                        systemImage: "tray.full",
                        accent: AppTheme.info
                    )

                    MetricTile(
                        label: "已入相册",
                        value: "\(exportedCount)",
                        systemImage: "photo.stack",
                        accent: AppTheme.success
                    )
                }

                DisclosureGroup("查看存储位置") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.downloadDirectoryPath.isEmpty ? "加载中..." : model.downloadDirectoryPath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppTheme.inkMuted)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            copyDownloadPath()
                        } label: {
                            Label("复制路径", systemImage: "doc.on.doc")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(AppTheme.surfaceMuted, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.downloadDirectoryPath.isEmpty)
                    }
                    .padding(.top, 12)
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .tint(AppTheme.ink)

                Button {
                    Task {
                        await model.refreshDownloads()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("刷新下载记录", systemImage: "arrow.clockwise")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func activeDownloadSection(_ progress: ActiveDownloadProgress) -> some View {
        CustomCard(title: "传输进度") {
            DownloadProgressDetails(progress: progress)
        }
    }

    private var recordsSection: some View {
        CustomCard(title: "最近完成") {
            if model.downloads.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(AppTheme.inkMuted.opacity(0.5))

                    Text("还没有下载记录")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("从“照片”页选择内容后，下载历史会出现在这里。")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.downloads) { record in
                        DownloadRecordRow(record: record)
                        
                        if record.id != model.downloads.last?.id {
                            Divider()
                                .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
    }

    private func copyDownloadPath() {
        #if canImport(UIKit)
        UIPasteboard.general.string = model.downloadDirectoryPath
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.downloadDirectoryPath, forType: .string)
        #endif
    }
}
