//
//  PGLImageListOverlayView.swift
//  RiftEffects
//
//  Created by Will Loew-Blosser on 3/20/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import SwiftUI
import Photos

// MARK: - View Model

@MainActor
class PGLImageListViewModel: ObservableObject {

    struct AssetSection: Identifiable {
        let id = UUID()
        let attributeName: String
        let imageList: PGLImageList
        var assets: [PGLAsset]
    }

    @Published var sections: [AssetSection] = []

    func loadFromFilter(_ filter: PGLSourceFilter) {
        sections = filter.imageAttributes().compactMap { attr in
            guard let list = attr.inputCollection, !list.isEmpty() else { return nil }
            let name = attr.attributeDisplayName ?? attr.attributeName ?? "Images"
            return AssetSection(attributeName: name, imageList: list, assets: list.imageAssets)
        }
    }

    func removeAsset(in sectionIndex: Int, at offsets: IndexSet) {
        sections[sectionIndex].assets.remove(atOffsets: offsets)
        sections[sectionIndex].imageList.imageAssets = sections[sectionIndex].assets
    }

    func moveAsset(in sectionIndex: Int, from offsets: IndexSet, to destination: Int) {
        sections[sectionIndex].assets.move(fromOffsets: offsets, toOffset: destination)
        sections[sectionIndex].imageList.imageAssets = sections[sectionIndex].assets
    }
}

// MARK: - Asset Thumbnail Row

struct PGLAssetRowView: View {
    let pglAsset: PGLAsset
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                if pglAsset.asset.mediaType == .video {
                    Label("Video", systemImage: "video")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let date = pglAsset.asset.creationDate {
                    Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.gray.opacity(0.3)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
        }
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        let size = CGSize(width: 120, height: 120)
        PHImageManager.default().requestImage(
            for: pglAsset.asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }
    }
}

// MARK: - Overlay View

struct PGLImageListOverlayView: View {
    @ObservedObject var viewModel: PGLImageListViewModel
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                contentList
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Filter Images")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
    }

    private var contentList: some View {
        Group {
            if viewModel.sections.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.sections.indices, id: \.self) { sectionIndex in
                        let section = viewModel.sections[sectionIndex]
                        Section {
                            ForEach(section.assets, id: \.localIdentifier) { pglAsset in
                                PGLAssetRowView(pglAsset: pglAsset)
                                    .listRowBackground(Color.black.opacity(0.35))
                            }
                            .onDelete { offsets in
                                viewModel.removeAsset(in: sectionIndex, at: offsets)
                            }
                            .onMove { from, to in
                                viewModel.moveAsset(in: sectionIndex, from: from, to: to)
                            }
                        } header: {
                            Text(section.attributeName)
                                .foregroundColor(.white.opacity(0.7))
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .environment(\.editMode, .constant(.active))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.4))
            Text("No images assigned to this filter")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
}
