import SwiftUI

struct DownloadsContainerView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel

    var body: some View {
        DownloadsView(
            downloads: viewModel.downloads,
            activeDownloadProgress: viewModel.activeDownloadProgress,
            onRefreshDownloads: {
                Task {
                    await viewModel.refreshDownloads()
                }
            }
        )
    }
}
