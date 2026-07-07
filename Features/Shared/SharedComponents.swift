import SwiftUI

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
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.inkMuted)
                    .padding(.horizontal, 2)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }
}

struct GridRowItem: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.inkMuted)
                .frame(width: 16, height: 16)

            Text(label)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.inkMuted)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

struct DownloadProgressDetails: View {
    let progress: ActiveDownloadProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(progress.fileName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Text("第 \(progress.currentItemNumber) / \(progress.totalItemCount) 项")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(AppTheme.inkMuted)
                }

                Spacer()

                Text(progress.percentageText)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.accentStrong)
            }

            ProgressView(value: progress.fractionCompleted)
                .tint(AppTheme.accentStrong)
                .scaleEffect(y: 0.75, anchor: .center)

            Text("\(Formatters.fileSize(progress.bytesTransferred)) / \(Formatters.fileSize(progress.totalBytes))")
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .foregroundStyle(AppTheme.inkMuted)
        }
    }
}
