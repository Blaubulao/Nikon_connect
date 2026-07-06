import SwiftUI

struct DownloadRecordRow: View {
    let record: DownloadRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon)
                .font(.system(size: 18))
                .foregroundStyle(fileColor)
                .frame(width: 36, height: 36)
                .background(fileColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(record.fileName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if record.exportedToPhotoLibrary {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已入相册")
                        }
                        .font(.system(size: 9, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(red: 0.13, green: 0.75, blue: 0.42))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.13, green: 0.75, blue: 0.42).opacity(0.08))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "internaldrive")
                            Text("仅沙盒")
                        }
                        .font(.system(size: 9, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 12) {
                    Text(Formatters.fileSize(record.byteSize))
                        .font(.system(.caption, design: .monospaced))
                    
                    Text(Formatters.shortDate(record.completedAt))
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(.secondary)
                
                Text(record.savedURL.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: String {
        let ext = record.savedURL.pathExtension.lowercased()
        if ext == "mov" || ext == "mp4" {
            return "film"
        } else if ext == "nef" || ext == "nrw" || ext == "raw" {
            return "camera.aperture"
        } else {
            return "photo"
        }
    }

    private var fileColor: Color {
        let ext = record.savedURL.pathExtension.lowercased()
        if ext == "mov" || ext == "mp4" {
            return .red
        } else if ext == "nef" || ext == "nrw" || ext == "raw" {
            return .orange
        } else {
            return Color(red: 0.20, green: 0.50, blue: 0.98)
        }
    }
}
