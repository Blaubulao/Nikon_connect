import Foundation
import SwiftUI

@MainActor
final class DownloadManagerViewModel: ObservableObject {
    @Published var downloads: [DownloadRecord] = []
    @Published var downloadDirectoryPath = ""
    @Published var activeDownloadProgress: ActiveDownloadProgress?
    @Published var isDownloading = false

    private let downloadStore: any DownloadStoring
    private let photoLibraryExportService: any PhotoLibraryExporting
    private let sessionCoordinator: CameraSessionCoordinator
    private let shell: AppShellViewModel

    init(
        downloadStore: any DownloadStoring,
        photoLibraryExportService: any PhotoLibraryExporting,
        sessionCoordinator: CameraSessionCoordinator,
        shell: AppShellViewModel
    ) {
        self.downloadStore = downloadStore
        self.photoLibraryExportService = photoLibraryExportService
        self.sessionCoordinator = sessionCoordinator
        self.shell = shell
    }

    func canDownload(_ assets: [PhotoAsset], session: CameraSession?) -> Bool {
        session?.capabilities.contains(.downloadAssets) == true && !assets.isEmpty && !isDownloading
    }

    func refreshDownloads() async {
        do {
            let directory = try await downloadStore.downloadsDirectoryURL()
            let records = try await downloadStore.listRecords()
            downloadDirectoryPath = directory.path
            downloads = records
        } catch {
            shell.handle(error)
        }
    }

    @discardableResult
    func downloadAssets(_ assets: [PhotoAsset], autoExportToPhotoLibrary: Bool) async -> Bool {
        guard let session = sessionCoordinator.activeSession,
              let transport = sessionCoordinator.activeTransport else {
            shell.handle(CameraAppError.notConnected)
            return false
        }

        guard !assets.isEmpty else { return true }

        isDownloading = true
        shell.setGlobalActivityTitle(CameraWorkflowState.downloading.title)
        activeDownloadProgress = nil
        shell.appendLog("正在下载 \(assets.count) 个文件...")
        defer {
            activeDownloadProgress = nil
            isDownloading = false
            shell.setGlobalActivityTitle(nil)
        }

        var exportFailures: [String] = []

        do {
            for (index, asset) in assets.enumerated() {
                let itemNumber = index + 1
                let totalItemCount = assets.count
                shell.appendLog("开始下载 \(asset.fileName)（\(itemNumber)/\(totalItemCount)）")

                updateActiveDownloadProgress(
                    for: asset,
                    itemNumber: itemNumber,
                    totalItemCount: totalItemCount,
                    transportProgress: DownloadTransferProgress(
                        bytesTransferred: 0,
                        totalBytes: max(asset.byteSize, 0),
                        resumedCount: 0,
                        currentOffset: 0,
                        chunkSize: 0
                    )
                )

                let temporaryURL = try await transport.downloadAssetToTemporaryFile(
                    asset,
                    from: session
                ) { progress in
                    await MainActor.run {
                        self.updateActiveDownloadProgress(
                            for: asset,
                            itemNumber: itemNumber,
                            totalItemCount: totalItemCount,
                            transportProgress: progress
                        )
                    }
                }
                var didPersistDownload = false
                defer {
                    if !didPersistDownload {
                        try? FileManager.default.removeItem(at: temporaryURL)
                    }
                }

                let measuredSize = Self.fileSize(at: temporaryURL)
                let finalSize = measuredSize > 0
                    ? measuredSize
                    : max(activeDownloadProgress?.totalBytes ?? 0, max(asset.byteSize, 0))
                let fallbackChunkSize = max(activeDownloadProgress?.chunkSize ?? 0, finalSize)
                updateActiveDownloadProgress(
                    for: asset,
                    itemNumber: itemNumber,
                    totalItemCount: totalItemCount,
                    transportProgress: DownloadTransferProgress(
                        bytesTransferred: finalSize,
                        totalBytes: finalSize,
                        resumedCount: activeDownloadProgress?.resumedCount ?? 0,
                        currentOffset: finalSize,
                        chunkSize: fallbackChunkSize
                    ),
                    fallbackToAssetByteSize: false
                )

                var record = try await downloadStore.storeDownloadedFile(at: temporaryURL, from: asset)
                didPersistDownload = true
                shell.appendLog("已将 \(record.fileName) 保存到应用存储。")

                if autoExportToPhotoLibrary {
                    do {
                        try await photoLibraryExportService.exportFile(at: record.savedURL)
                        record = try await downloadStore.markExported(recordID: record.id)
                        shell.appendLog("已将 \(record.fileName) 导出到系统相册。")
                    } catch {
                        exportFailures.append("\(record.fileName): \(shell.userFacingMessage(for: error))")
                    }
                }
            }

            shell.appendLog("已下载 \(assets.count) 个文件。")
            await refreshDownloads()

            if !exportFailures.isEmpty {
                shell.showAlert(
                    title: "下载已完成，但有提示",
                    message: exportFailures.joined(separator: "\n")
                )
            }
            return true
        } catch {
            shell.handle(error)
            return false
        }
    }

    private func updateActiveDownloadProgress(
        for asset: PhotoAsset,
        itemNumber: Int,
        totalItemCount: Int,
        transportProgress: DownloadTransferProgress,
        fallbackToAssetByteSize: Bool = true
    ) {
        let knownTotal = fallbackToAssetByteSize ? max(asset.byteSize, 0) : 0
        let resolvedTotal = max(max(transportProgress.totalBytes, transportProgress.bytesTransferred), knownTotal)
        let resolvedTransferred = min(max(transportProgress.bytesTransferred, 0), resolvedTotal)
        let resolvedOffset = min(max(transportProgress.currentOffset, resolvedTransferred), resolvedTotal)

        activeDownloadProgress = ActiveDownloadProgress(
            fileName: asset.fileName,
            currentItemNumber: itemNumber,
            totalItemCount: totalItemCount,
            bytesTransferred: resolvedTransferred,
            totalBytes: resolvedTotal,
            resumedCount: max(transportProgress.resumedCount, 0),
            currentOffset: resolvedOffset,
            chunkSize: max(transportProgress.chunkSize, 0)
        )
    }

    private static func fileSize(at url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
    }
}
