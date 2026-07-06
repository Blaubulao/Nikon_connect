import Foundation

actor DownloadStore {
    private let fileManager: FileManager
    private let rootDirectory: URL

    init(fileManager: FileManager = .default, rootDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.rootDirectory = documents.appendingPathComponent("Nikon Connect", isDirectory: true)
        }
    }

    func downloadsDirectoryURL() throws -> URL {
        let url = rootDirectory.appendingPathComponent("Downloads", isDirectory: true)
        try ensureDirectoryExists(at: url)
        return url
    }

    func listRecords() throws -> [DownloadRecord] {
        let manifest = try loadManifest()
        return manifest.sorted { $0.completedAt > $1.completedAt }
    }

    func store(data: Data, from asset: PhotoAsset) throws -> DownloadRecord {
        let directory = try downloadsDirectoryURL()
        let destination = uniqueDestinationURL(in: directory, fileName: asset.fileName)

        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw CameraAppError.fileSystemFailure(error.localizedDescription)
        }

        let record = DownloadRecord(
            sourceAssetIdentifier: asset.remoteIdentifier,
            fileName: destination.lastPathComponent,
            savedURL: destination,
            byteSize: Int64(data.count),
            exportedToPhotoLibrary: false
        )

        var manifest = try loadManifest()
        manifest.append(record)
        try saveManifest(manifest)
        return record
    }

    func markExported(recordID: UUID) throws -> DownloadRecord {
        var manifest = try loadManifest()
        guard let index = manifest.firstIndex(where: { $0.id == recordID }) else {
            throw CameraAppError.fileSystemFailure("找不到下载记录。")
        }

        manifest[index].exportedToPhotoLibrary = true
        try saveManifest(manifest)
        return manifest[index]
    }

    private func manifestURL() throws -> URL {
        try downloadsDirectoryURL().appendingPathComponent("downloads-manifest.json")
    }

    private func ensureDirectoryExists(at url: URL) throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw CameraAppError.fileSystemFailure(error.localizedDescription)
        }
    }

    private func uniqueDestinationURL(in directory: URL, fileName: String) -> URL {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension
        var candidate = directory.appendingPathComponent(fileName)
        var index = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let nextName = ext.isEmpty ? "\(baseName)-\(index)" : "\(baseName)-\(index).\(ext)"
            candidate = directory.appendingPathComponent(nextName)
            index += 1
        }

        return candidate
    }

    private func loadManifest() throws -> [DownloadRecord] {
        let url = try manifestURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let records = try JSONDecoder().decode([DownloadRecord].self, from: data)
            return records.filter { fileManager.fileExists(atPath: $0.savedURL.path) }
        } catch {
            throw CameraAppError.fileSystemFailure("无法读取下载清单：\(error.localizedDescription)")
        }
    }

    private func saveManifest(_ records: [DownloadRecord]) throws {
        let url = try manifestURL()

        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            throw CameraAppError.fileSystemFailure("无法写入下载清单：\(error.localizedDescription)")
        }
    }
}
