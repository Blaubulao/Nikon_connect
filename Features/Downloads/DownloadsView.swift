import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DownloadsView: View {
    let downloads: [DownloadRecord]
    let activeDownloadProgress: ActiveDownloadProgress?
    let onRefreshDownloads: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                overviewSection

                if let activeDownloadProgress {
                    activeDownloadSection(activeDownloadProgress)
                }

                recordsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("下载")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onRefreshDownloads) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var exportedCount: Int {
        downloads.filter(\.exportedToPhotoLibrary).count
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("下载记录")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 12) {
                MetricTile(
                    label: "记录数",
                    value: "\(downloads.count)",
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
        }
    }

    private func activeDownloadSection(_ progress: ActiveDownloadProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "传输进度")

            CustomCard {
                DownloadProgressDetails(progress: progress)
            }
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近完成")

            CustomCard {
                if downloads.isEmpty {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.inkMuted.opacity(0.4))

                        Text("暂无记录")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(downloads) { record in
                            DownloadRecordRow(record: record)

                            if record.id != downloads.last?.id {
                                Divider()
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
        }
    }
}
