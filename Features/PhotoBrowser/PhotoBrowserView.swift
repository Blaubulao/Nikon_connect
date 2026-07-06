import SwiftUI
import UIKit

struct PhotoBrowserView: View {
    @ObservedObject var model: AppModel

    @State private var activeFilter: PreviewFilter = .all
    @State private var gridColumnCount = 3
    @State private var previewSeed: PhotoPreviewSeed?

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if model.photoAssets.isEmpty {
                emptyStateView
            } else if filteredAssets.isEmpty {
                filteredEmptyStateView
            } else {
                assetGrid
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $previewSeed) { seed in
            PhotoAssetPreviewScreen(
                model: model,
                assets: filteredAssets,
                initialAssetID: seed.assetID
            )
        }
        .toolbar {
            ToolbarItem(placement: leadingToolbarPlacement) {
                Button {
                    Task {
                        await model.refreshPhotos()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!model.canRefreshPhotos)
            }

            ToolbarItem(placement: .principal) {
                Menu {
                    Button {
                        gridColumnCount = 3
                    } label: {
                        menuRow(title: "三列预览", isSelected: gridColumnCount == 3)
                    }

                    Button {
                        gridColumnCount = 4
                    } label: {
                        menuRow(title: "四列预览", isSelected: gridColumnCount == 4)
                    }

                    Divider()

                    Label("当前按时间倒序", systemImage: "arrow.down.to.line.compact")
                } label: {
                    HStack(spacing: 4) {
                        Text("显示选项")
                            .font(.headline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            ToolbarItem(placement: trailingToolbarPlacement) {
                Menu {
                    Button("全选") {
                        model.selectAllAssets()
                    }

                    Button("清空选择") {
                        model.clearSelection()
                    }
                } label: {
                    Text(model.selectedAssetsCount == 0 ? "选择" : "已选 \(model.selectedAssetsCount)")
                        .font(.body.weight(.semibold))
                }
                .disabled(model.photoAssets.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.photoAssets.isEmpty {
                bottomActionBar
            }
        }
    }

    private var filteredAssets: [PhotoAsset] {
        model.photoAssets.filter { activeFilter.matches($0) }
    }

    private var gridItems: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: gridColumnCount
        )
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(PreviewFilter.allCases) { filter in
                let isSelected = activeFilter == filter
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        activeFilter = filter
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filter.systemImageName)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                        Text(filter.title)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(isSelected ? .black : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? Color(red: 0.99, green: 0.85, blue: 0.05) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var assetGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                summaryRow

                LazyVGrid(columns: gridItems, spacing: 6) {
                    ForEach(filteredAssets) { asset in
                        PhotoAssetGridTile(
                            model: model,
                            asset: asset,
                            isSelected: model.selectedAssetIDs.contains(asset.id)
                        ) {
                            model.toggleSelection(for: asset)
                        }
                        .onTapGesture {
                            previewSeed = PhotoPreviewSeed(assetID: asset.id)
                        }
                    }
                }

                if model.hasMorePhotos {
                    Button {
                        Task {
                            await model.loadMorePhotos()
                        }
                    } label: {
                        Label("继续读取更多", systemImage: "rectangle.stack.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.canLoadMorePhotos)
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 92)
        }
    }

    private var summaryRow: some View {
        HStack {
            Text(activeFilter.summaryTitle(for: filteredAssets.count))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(model.hasMorePhotos ? "已加载部分内容" : "已全部读取")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.6))
                .frame(width: 100, height: 100)
                .background(Color.primary.opacity(0.03), in: Circle())
            
            VStack(spacing: 8) {
                Text("还没有读取到照片")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                
                Text("请先回到“连接”建立会话，然后在此处按格式查看缩略图列表。")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if model.canRefreshPhotos {
                Button {
                    Task {
                        await model.refreshPhotos()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title3)
                        Text("读取首批照片")
                            .font(.system(.body, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.99, green: 0.85, blue: 0.05))
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.99, green: 0.85, blue: 0.05).opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var filteredEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.6))
                .frame(width: 100, height: 100)
                .background(Color.primary.opacity(0.03), in: Circle())
            
            VStack(spacing: 8) {
                Text("当前筛选下没有内容")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                
                Text("相机中可能不包含该格式的文件，您可以切换格式，或尝试载入更多照片。")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            HStack(spacing: 12) {
                Button("显示全部") {
                    withAnimation {
                        activeFilter = .all
                    }
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
                .buttonStyle(.plain)
                
                if model.hasMorePhotos {
                    Button {
                        Task {
                            await model.loadMorePhotos()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("继续读取更多")
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.99, green: 0.85, blue: 0.05))
                        .clipShape(Capsule())
                    }
                    .disabled(!model.canLoadMorePhotos)
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("已选择 \(model.selectedAssetsCount) 项")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                
                Text(model.autoExportToPhotoLibrary ? "将自动导出到系统相册" : "将保存到应用存储")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task {
                    await model.downloadSelectedAssets()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                    Text("开始下载")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                }
                .foregroundStyle(model.canDownloadSelection ? .black : .secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    model.canDownloadSelection
                    ? LinearGradient(colors: [Color(red: 0.99, green: 0.85, blue: 0.05), Color(red: 0.98, green: 0.70, blue: 0.03)], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color(.systemFill)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(Capsule())
                .shadow(color: model.canDownloadSelection ? Color(red: 0.99, green: 0.85, blue: 0.05).opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            }
            .disabled(!model.canDownloadSelection)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func menuRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }

    private var leadingToolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarLeading
        #else
        .automatic
        #endif
    }

    private var trailingToolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .primaryAction
        #endif
    }
}

private struct PhotoPreviewSeed: Identifiable {
    let assetID: UUID
    let id = UUID()
}

private enum PreviewFilter: CaseIterable, Identifiable {
    case all
    case jpeg
    case raw
    case movie

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .jpeg:
            return "JPEG"
        case .raw:
            return "RAW"
        case .movie:
            return "视频"
        }
    }

    var systemImageName: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .jpeg:
            return "photo"
        case .raw:
            return "camera.aperture"
        case .movie:
            return "video"
        }
    }

    func matches(_ asset: PhotoAsset) -> Bool {
        switch self {
        case .all:
            return true
        case .jpeg:
            return asset.kind == .jpeg || asset.kind == .png
        case .raw:
            return asset.kind == .raw
        case .movie:
            return asset.kind == .movie
        }
    }

    func summaryTitle(for count: Int) -> String {
        switch self {
        case .all:
            return "共 \(count) 项"
        default:
            return "\(title) \(count) 项"
        }
    }
}

private struct PhotoAssetGridTile: View {
    private static let photoAspectRatio = 6016.0 / 4016.0

    @ObservedObject var model: AppModel
    let asset: PhotoAsset
    let isSelected: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                PhotoAssetThumbnailPreview(model: model, asset: asset)
                    .aspectRatio(Self.photoAspectRatio, contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)

                HStack {
                    Text(asset.kind.badgeTitle)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(kindBadgeColor.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Spacer(minLength: 8)
                }
                .padding(8)

                Button(action: onToggleSelection) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(isSelected ? 0.0 : 0.2))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isSelected ? Color(red: 0.99, green: 0.85, blue: 0.05) : .white.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.99, green: 0.85, blue: 0.05) : Color.primary.opacity(0.06),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.fileName)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(1)

                Text(Formatters.shortDate(asset.captureDate))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.06 : 0.02), radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
    }

    private var kindBadgeColor: Color {
        switch asset.kind {
        case .raw:
            return Color.orange
        case .movie:
            return Color.red
        default:
            return Color.black
        }
    }
}

private struct PhotoAssetThumbnailPreview: View {
    @ObservedObject var model: AppModel
    let asset: PhotoAsset

    @State private var thumbnailData: Data?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(placeholderBackground)

            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: asset.kind.systemImageName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }

                    Text(asset.kind.badgeTitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: asset.remoteIdentifier) {
            guard thumbnailData == nil, !isLoading else { return }
            isLoading = true
            thumbnailData = await model.thumbnailData(for: asset)
            isLoading = false
        }
    }

    private var thumbnailImage: UIImage? {
        guard let thumbnailData else {
            return nil
        }

        return UIImage(data: thumbnailData)
    }

    private var placeholderBackground: LinearGradient {
        let seed = asset.fileName.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult * 31 + Int(scalar.value)) % 360
        }
        let hue = Double(seed) / 360

        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.15, brightness: 0.35),
                Color(hue: (hue + 0.05).truncatingRemainder(dividingBy: 1), saturation: 0.20, brightness: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct PhotoAssetPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var model: AppModel
    let assets: [PhotoAsset]
    let initialAssetID: UUID

    @State private var currentIndex: Int

    init(model: AppModel, assets: [PhotoAsset], initialAssetID: UUID) {
        self.model = model
        self.assets = assets
        self.initialAssetID = initialAssetID

        let resolvedIndex = assets.firstIndex(where: { $0.id == initialAssetID }) ?? 0
        _currentIndex = State(initialValue: resolvedIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                previewContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
        }
    }

    private var currentAsset: PhotoAsset {
        let clampedIndex = min(max(currentIndex, 0), max(assets.count - 1, 0))
        return assets[clampedIndex]
    }

    private var canGoToPrevious: Bool {
        currentIndex > 0
    }

    private var canGoToNext: Bool {
        currentIndex < assets.count - 1
    }

    private var isSelected: Bool {
        model.selectedAssetIDs.contains(currentAsset.id)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(currentAsset.fileName)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(Formatters.shortDate(currentAsset.captureDate))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(currentAsset.kind.badgeTitle)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.99, green: 0.85, blue: 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text("\(currentIndex + 1) / \(assets.count)")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.6), Color.clear], startPoint: .top, endPoint: .bottom)
        )
    }

    private var previewContent: some View {
        ZStack {
            PhotoAssetPreviewPage(model: model, asset: currentAsset)
                .id(currentAsset.id)

            HStack {
                navigationButton(
                    systemImage: "chevron.left",
                    isEnabled: canGoToPrevious
                ) {
                    currentIndex -= 1
                }

                Spacer()

                navigationButton(
                    systemImage: "chevron.right",
                    isEnabled: canGoToNext
                ) {
                    currentIndex += 1
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentAsset.kind == .movie ? "视频文件" : "照片文件")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text(Formatters.fileSize(currentAsset.byteSize))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer(minLength: 12)

                Button {
                    model.toggleSelection(for: currentAsset)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        Text(isSelected ? "已选择" : "选择照片")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(isSelected ? .black : .white)
                    .frame(minWidth: 110)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isSelected 
                        ? Color(red: 0.99, green: 0.85, blue: 0.05) 
                        : Color.white.opacity(0.15)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    @ViewBuilder
    private func navigationButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.28)
        .disabled(!isEnabled)
    }
}

private struct PhotoAssetPreviewPage: View {
    @ObservedObject var model: AppModel
    let asset: PhotoAsset

    @State private var previewData: Data?
    @State private var isLoading = false
    @State private var didFailToLoad = false

    var body: some View {
        Group {
            if let image = previewImage {
                ZoomablePhotoPreview(image: image)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            } else if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)

                    Text("正在载入预览")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: asset.kind.systemImageName)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))

                    Text(didFailToLoad ? "暂时无法显示预览" : asset.kind.badgeTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
        }
        .task(id: asset.remoteIdentifier) {
            await loadPreview()
        }
    }

    private var previewImage: UIImage? {
        guard let previewData else {
            return nil
        }

        return UIImage(data: previewData)
    }

    private func loadPreview() async {
        guard previewData == nil, !isLoading else { return }
        isLoading = true
        didFailToLoad = false

        if let thumbnail = await model.thumbnailData(for: asset) {
            previewData = thumbnail
        }

        isLoading = previewData == nil

        if let upgradedPreview = await model.previewData(for: asset) {
            previewData = upgradedPreview
            isLoading = false
            return
        }

        didFailToLoad = previewData == nil
        isLoading = false
    }
}

private struct ZoomablePhotoPreview: View {
    private static let minimumScale: CGFloat = 1
    private static let maximumScale: CGFloat = 5

    let image: UIImage

    @State private var steadyScale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var steadyOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(magnificationGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if currentScale > 1 {
                            resetTransform()
                        } else {
                            steadyScale = 2
                        }
                    }
                }
        }
    }

    private var currentScale: CGFloat {
        min(max(Self.minimumScale, steadyScale * gestureScale), Self.maximumScale)
    }

    private var currentOffset: CGSize {
        guard currentScale > 1 else {
            return .zero
        }

        return CGSize(
            width: steadyOffset.width + dragOffset.width,
            height: steadyOffset.height + dragOffset.height
        )
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                steadyScale = min(max(Self.minimumScale, steadyScale * value), Self.maximumScale)
                gestureScale = 1

                if steadyScale <= 1.01 {
                    resetTransform()
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard currentScale > 1 else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard currentScale > 1 else {
                    resetTransform()
                    return
                }

                steadyOffset = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
                dragOffset = .zero
            }
    }

    private func resetTransform() {
        steadyScale = 1
        gestureScale = 1
        steadyOffset = .zero
        dragOffset = .zero
    }
}
