import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DownloadsContainerView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel

    var body: some View {
        DownloadsView(
            downloads: viewModel.downloads,
            downloadDirectoryPath: viewModel.downloadDirectoryPath,
            activeDownloadProgress: viewModel.activeDownloadProgress,
            onRefreshDownloads: {
                Task {
                    await viewModel.refreshDownloads()
                }
            },
            onCopyDownloadPath: {
                copyDownloadPath()
            }
        )
    }

    private func copyDownloadPath() {
        #if canImport(UIKit)
        UIPasteboard.general.string = viewModel.downloadDirectoryPath
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.downloadDirectoryPath, forType: .string)
        #endif
    }
}
