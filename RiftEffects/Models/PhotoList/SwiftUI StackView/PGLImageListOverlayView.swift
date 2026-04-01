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

    struct ParmSection: Identifiable {
        let id = UUID()
        let attributeName: String
        var imageList: PGLImageList
        // assets and cachedImages are internal vars of the imageList
        var assets: [PGLAsset]
        var cachedImages: [Int: PGLImageScaler]
    }

    @Published var filterParms: [ParmSection] = []
//    @Published var selection: Set<String> = []

    func loadFromFilter(_ filter: PGLSourceFilter) {
        // PGLImageController loads from selected filter
        // then opens PGLImageListOverlayView with this model
        filterParms = filter.imageAttributes().compactMap { attr -> ParmSection? in
            guard let list = attr.inputCollection, !list.isEmpty() else { return nil }
            let name = attr.attributeDisplayName ?? attr.attributeName ?? "Images"
            return ParmSection(attributeName: name, imageList: list, assets: list.imageAssets,
                cachedImages: list.cachedImages
            )
//            return PGLStackItem
        }
    }

    func removeAsset(in parmId: UUID, at imageListIndex: Int) {
        guard let parmIndex = filterParms.firstIndex(where: { $0.id == parmId }) else { return }

        // perform remove on the imageList
        filterParms[parmIndex].imageList.removeImage(at: imageListIndex)

    }

    func moveAsset(in parmId: UUID, from offsets: IndexSet, to destination: Int) {
        guard let parmIndex = filterParms.firstIndex(where: { $0.id == parmId }) else { return }
//        filterParms[parmIndex].assets.move(fromOffsets: offsets, toOffset: destination)
        filterParms[parmIndex].imageList.moveContentsFrom(fromOffsets: offsets, toOffset: destination )


        // filterParms[idx].imageList.imageAssets = filterParms[idx].assets
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
    let id = UUID()

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
    // @ObservedObject var viewModel: PGLImageListViewModel
    @EnvironmentObject var viewModel: PGLImageListViewModel
    var onDismiss: () -> Void
    @State private var editMode: EditMode = .inactive


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
            if viewModel.filterParms.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.filterParms) { imageAttributeSection in
                        Section {
                            ForEach(imageAttributeSection.assets.indices, id: \.self) { assetIndex in
                                let pglAsset = imageAttributeSection.assets[assetIndex]
                                let cachedImage = imageAttributeSection.imageList.cachedImages[assetIndex]?.image
                                PGLAssetRowView(pglAsset: pglAsset, cachedImage: cachedImage)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                viewModel.removeAsset(in: imageAttributeSection.id,  at: assetIndex)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                            .onMove { from, to in
                                withAnimation {
                                    viewModel.moveAsset(in: imageAttributeSection.id, from: from, to: to)
                                }
                            }
                            .listRowBackground(Color.black.opacity(0.35))

                        } header: {
                            Text(imageAttributeSection.attributeName)
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
