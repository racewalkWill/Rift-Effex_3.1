//
//  PGLImageListOverlayView.swift
//  RiftEffects
//
//  Created by Will Loew-Blosser on 3/20/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import SwiftUI
import Photos
import CoreImage


// MARK: - View Model

@MainActor
class PGLImageListViewModel: ObservableObject {

    struct AssetSection: Identifiable {
        let id = UUID()
        let attributeName: String
        let imageList: PGLImageList
        var assets: [PGLAsset]
        var cachedImages: [Int: PGLImageScaler]
    }

    @Published var sections: [AssetSection] = []
//    @Published var selection: Set<String> = []

    func loadFromFilter(_ filter: PGLSourceFilter) {
        sections = filter.imageAttributes().compactMap { attr -> AssetSection? in
            guard let list = attr.inputCollection, !list.isEmpty() else { return nil }
            let name = attr.attributeDisplayName ?? attr.attributeName ?? "Images"
            return AssetSection(attributeName: name, imageList: list, assets: list.imageAssets,
                cachedImages: list.cachedImages)
//            return PGLStackItem
        }
    }

    func removeAsset(in sectionID: UUID, at offsets: IndexSet) {
        guard let idx = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[idx].assets.remove(atOffsets: offsets)
        sections[idx].imageList.imageAssets = sections[idx].assets
    }

    func moveAsset(in sectionID: UUID, from offsets: IndexSet, to destination: Int) {
        guard let idx = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[idx].assets.move(fromOffsets: offsets, toOffset: destination)
        sections[idx].imageList.imageAssets = sections[idx].assets
    }

//    func selectAsset(in sectionID: UUID, at index: Int) {
//        guard let idx = sections.firstIndex(where: { $0.id == sectionID }) else { return }
//        sections[idx].assets[index].isSelected.toggle()
//        sections[idx].imageList.imageAssets = sections[idx].assets
//    }
}

// MARK: - Asset Thumbnail Row

struct PGLAssetRowView: View {
    let pglAsset: PGLAsset
    let cachedImage: CIImage?
    
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        HStack(spacing: 10) {
            thumbnailView
                .frame(width: 80, height: 60)
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
//        Button {
//            // call removeAsset(in sectionID;, at offsets: )
////            guard let index = symbols.firstIndex(of: symbol) else { return }
////            withAnimation {
////                _ = symbols.remove(at: index)
////            }
//        } label: {
//            Image(systemName: "xmark.square.fill")
//                        .font(.title)
//                        .symbolRenderingMode(.palette)
//                        .foregroundStyle(.white, Color.red)
//        }
//        .offset(x: 7, y: -7)
    }

    private func loadThumbnail() {
        guard thumbnail == nil, let ciImage = cachedImage else { return }
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let smallSize = CGSize(width: 120, height: 120)
            let source = UIImage(cgImage: cgImage)
            Task {
                let prepared = await source.byPreparingThumbnail(ofSize: smallSize)
                await MainActor.run { thumbnail = prepared }
            }
        }
    }
}

// MARK: - Overlay View

struct PGLImageListOverlayView: View {
    @ObservedObject var viewModel: PGLImageListViewModel
    var onDismiss: () -> Void
    @State private var editMode: EditMode = .active

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
//                List(selection: $viewModel.selection) {
                List {
                    ForEach(viewModel.sections) { section in
                        Section {
                            ForEach(section.assets) { pglAsset in
                                let assetIndex = section.assets.firstIndex(of: pglAsset)
                                PGLAssetRowView(pglAsset: pglAsset, cachedImage: assetIndex.flatMap { section.cachedImages[$0]?.image })
                                    .listRowBackground(Color.black.opacity(0.35))
//                                Button {
//                                    if let index = assetIndex {
//                                        withAnimation {
//                                            viewModel.removeAsset(in: section.id, at: IndexSet(integer: index))
//                                        }
//                                    }
//                                }
//                                label: {
//                                    Image(systemName: "xmark.square.fill")
//                                                .font(.title)
//                                                .symbolRenderingMode(.palette)
//                                                .foregroundStyle(.white, Color.red)
//                                }
//                                .offset(x: 7, y: -7)
                            }
                            .onDelete { offsets in
                                viewModel.removeAsset(in: section.id, at: offsets)
                            }
                            .onMove { from, to in
                                viewModel.moveAsset(in: section.id, from: from, to: to)
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
                .environment(\.editMode, $editMode)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.4))
            Text("Empty")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
}
