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


    @Published var filterParms: [ParmSection] = []
    @Published var isTransitionFilter = false

//    @Published var selection: Set<String> = []

    func loadFromFilter(_ filter: PGLSourceFilter) {
        // PGLImageController loads from selected filter
        // then opens PGLImageListOverlayView with this model
        isTransitionFilter = filter.isTransitionCategoryFilter()
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

        filterParms[parmIndex].remove(at: imageListIndex)
    }

    func addAssets(in parmId: UUID, assets: [PGLAsset]) {
        guard let parmIndex = filterParms.firstIndex(where: { $0.id == parmId }) else { return }
        if isTransitionFilter {
            filterParms[parmIndex].add(assets: assets)
        } else {
            // remove the old asset and replace with the new selected image
            filterParms[parmIndex].replace(assets: assets)
        }

    }

    func moveAsset(in parmId: UUID, from offsets: IndexSet, to destination: Int){
        guard let parmIndex = filterParms.firstIndex(where: { $0.id == parmId }) else { return }

        filterParms[parmIndex].move(fromOffsets: offsets, toOffset: destination)
    }

}

// MARK:  Parm Section
 struct ParmSection: Identifiable, Hashable {
    let id = UUID()
    let attributeName: String
    var imageList: PGLImageList
    // assets and cachedImages are internal vars of the imageList
    var assets: [PGLAsset]
    var cachedImages: [Int: PGLImageScaler]

    static func == (lhs: ParmSection, rhs: ParmSection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

     @MainActor mutating func add(assets list: [PGLAsset]) {
         let oldLastIndex = assets.count - 1 // zero based index
         imageList.append(assets:  list)
         assets.append(contentsOf: list)
         let newImages = list.map { $0.imageFrom() }
         for i in 1...newImages.count  {
             let thisImage = newImages[i - 1] ?? CIImage.empty()
             let scaler = PGLImageScaler(image: thisImage)
             let cacheIndex = oldLastIndex + i
             cachedImages[cacheIndex] = scaler
             imageList.cachedImages[cacheIndex] = scaler
         }

     }

     @MainActor mutating func remove(at index: Int) {
         imageList.removeImage(at: index)
         assets.remove(at: index)
         // Rebuild cachedImages to match new indices after removal
         var newCached = [Int: PGLImageScaler]()
         for i in assets.indices {
             let oldIndex = i < index ? i : i + 1
             if let scaler = cachedImages[oldIndex] {
                 newCached[i] = scaler
             }
         }
         cachedImages = newCached
     }

     @MainActor mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
         imageList.moveContentsFrom(fromOffsets: offsets, toOffset: destination)
         assets.move(fromOffsets: offsets, toOffset: destination)
         // Cached images are index-keyed; clear and let them re-cache on access
         cachedImages.removeAll()
     }

     @MainActor mutating func replace(assets list: [PGLAsset]) {
         // usually just replacing the single image with another single image
         imageList.removeAll()
         assets.removeAll()
         cachedImages.removeAll()

         add(assets: list)
     }


}

// MARK: - Asset Thumbnail Row

struct PGLAssetRowView: View {
    let pglAsset: PGLAsset
    let cachedImage: CIImage?
    let parentSection: ParmSection

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
    @State private var isAddingPhoto = false
    @State private var selectedRow: RowID?

    private struct RowID: Hashable {
        let sectionID: UUID
        let assetIndex: Int
    }

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
            Text("Edit Images")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button {
                isAddingPhoto = true
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)

            }
            .disabled(selectedRow == nil)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.4))
    }

    private var contentList: some View {
        Group {
            if viewModel.filterParms.isEmpty {
                // filterParms is imageAttributes only
                emptyState
            } else {
                List {
                    ForEach(viewModel.filterParms) { imageAttributeSection in
                        sectionView(for: imageAttributeSection)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden) // .automatic covers the imageController view
                .background(Color.clear)
                .environment(\.editMode, $editMode)
                .sheet(isPresented: $isAddingPhoto) {
                    if let selectedRow {
                        PGLPhotoPicker(viewModel: viewModel, sectionID: selectedRow.sectionID)
                    }
                }
            }
        }
    }
    private func sectionView(for imageAttributeSection: ParmSection) -> some View {
        Section {
            ForEach(Array(imageAttributeSection.assets.enumerated()), id: \.element.id) { assetIndex, pglAsset in
                let cachedImage = imageAttributeSection.cachedImages[assetIndex]?.image
                let rowID = RowID(sectionID: imageAttributeSection.id, assetIndex: assetIndex)
                PGLAssetRowView(pglAsset: pglAsset, cachedImage: cachedImage, parentSection: imageAttributeSection)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            selectedRow = (selectedRow == rowID) ? nil : rowID
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedRow == rowID
                                  ? Color.accentColor.opacity(0.35)
                                  : Color.black.opacity(0.35))
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.removeAsset(in: imageAttributeSection.id, at: assetIndex)
                                    // assetIndex can shift when user drags or deletes form the list
                                // this assumes that assetIndex at creation time does not change
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
        } header: {
            Text(imageAttributeSection.attributeName)
                .foregroundColor(.white.opacity(0.7))
                .textCase(nil)
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
