import Foundation

protocol DownloadStoring: Sendable {
    func downloadsDirectoryURL() async throws -> URL
    func listRecords() async throws -> [DownloadRecord]
    func storeDownloadedFile(at sourceURL: URL, from asset: PhotoAsset) async throws -> DownloadRecord
    func markExported(recordID: UUID) async throws -> DownloadRecord
}

extension DownloadStore: DownloadStoring {}
