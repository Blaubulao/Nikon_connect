import SwiftUI

struct DownloadsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                storageSection
                recordsSection
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("下载")
    }

    private var storageSection: some View {
        CustomCard(title: "本地存储") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.99, green: 0.85, blue: 0.05))
                    
                    Text("沙盒下载路径")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    
                    Spacer()
                    
                    Button {
                        UIPasteboard.general.string = model.downloadDirectoryPath
                    } label: {
                        Label("复制路径", systemImage: "doc.on.doc")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.downloadDirectoryPath.isEmpty)
                }
                
                Text(model.downloadDirectoryPath.isEmpty ? "加载中..." : model.downloadDirectoryPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Button {
                    Task {
                        await model.refreshDownloads()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("刷新下载记录", systemImage: "arrow.clockwise")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recordsSection: some View {
        CustomCard(title: "下载历史") {
            if model.downloads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.top, 12)
                    
                    Text("无下载历史记录")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.downloads) { record in
                        DownloadRecordRow(record: record)
                        
                        if record.id != model.downloads.last?.id {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
}
