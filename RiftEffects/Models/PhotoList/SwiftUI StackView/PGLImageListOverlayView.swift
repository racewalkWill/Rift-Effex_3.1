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
    @Published var filterName: String = ""

//    @Published var selection: Set<String> = []

    func loadFromFilter(_ filter: PGLSourceFilter) {
        // PGLImageController loads from selected filter
        // then opens PGLImageListOverlayView with this model
        isTransitionFilter = filter.isTransitionCategoryFilter()
        filterName = filter.descriptorDisplayName ?? "Filter"

        filterParms = filter.imageAttributes().compactMap { attr -> ParmSection? in
            guard let list = attr.inputCollection, !list.isEmpty() else { return nil }
            let name = attr.attributeDisplayName ?? attr.attributeName ?? "Images"
            return ParmSection(attributeName: name, imageList: list, assets: list.imageAssets
//                               ,cachedImages: list.cachedImages
            )
//            return PGLStackItem
        }
    }

    func removeAsset(in parmId: UUID, at imageListIndex: Int) {
        guard let parmIndex = filterParms.firstIndex(where: { $0.id == parmId }) else { return }

        filterParms[parmIndex].remove(at: imageListIndex)
    }

    func addAssets(in rowID: RowID, assets: [PGLAsset]) {
        let parmId = rowID.sectionID

        guard let parmIndex = filterParms.firstIndex(where: { $0.id == parmId }) else { return }
        if isTransitionFilter {
            filterParms[parmIndex].add(assets: assets, afterRow: rowID.assetIndex)
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
//    var cachedImages: [Int: PGLImageScaler]

    static func == (lhs: ParmSection, rhs: ParmSection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

     @MainActor mutating func add(newAssets list: [PGLAsset]) {
         // first update the imageList and its assetIDs, assets and cachedImages
//         let oldLastIndex = assets.count - 1
//         imageList.addToCachedImages(newAssets: list, oldEndingIndex: oldLastIndex)
         imageList.append(assets:  list)

         // now update these parmSection vars
         assets.append(contentsOf: list)
//         cachedImages = imageList.cachedImages

     }

     @MainActor mutating func add(assets list: [PGLAsset], afterRow: Int) {
        // let oldLastIndex = assets.count - 1 // zero based index
//         let insertStartRow = afterRow

         imageList.insert(newAssets:  list, startingIndex: afterRow)
         // updates imageList.cachedImages to match

         assets.insert(contentsOf: list, at: afterRow)

//         cachedImages = imageList.cachedImages


     }

     @MainActor mutating func remove(at index: Int) {
         imageList.removeImage(at: index)
         assets.remove(at: index)
         // Rebuild cachedImages to match new indices after removal
//         var newCached = [Int: PGLImageScaler]()
//         for i in assets.indices {
//             let oldIndex = i < index ? i : i + 1
//             if let scaler = cachedImages[oldIndex] {
//                 newCached[i] = scaler
//             }
//         }
//         cachedImages = newCached
     }

     @MainActor mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
         imageList.moveContentsFrom(fromOffsets: offsets, toOffset: destination)
         assets.move(fromOffsets: offsets, toOffset: destination)
         // Cached images are index-keyed; clear and let them re-cache on access
//         cachedImages.removeAll()
     }

     @MainActor mutating func replace(assets list: [PGLAsset]) {
         // usually just replacing the single image with another single image
         imageList.removeAll()
         assets.removeAll()
//         cachedImages.removeAll()

         //add(assets: list,afterRow: 0)
         add(newAssets: list)
     }


}

// MARK: - Asset Thumbnail Row

struct PGLAssetRowView: View {
    let pglAsset: PGLAsset
    let cachedImage: UIImage?
    let parentSection: ParmSection

    @State private var thumbnail: UIImage? = nil

    var body: some View {
        HStack(spacing: 10) {
            thumbnailView
                .frame(width: 100, height: 100)
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
            // add a swipe indicator low value opacity
            Image(systemName: "chevron.left")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
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
        guard thumbnail == nil  else { return }
        thumbnail = pglAsset.thumbnail

//        let context = CIContext()
//        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
//            let smallSize = CGSize(width: 120, height: 120)
//            let source = UIImage(cgImage: cgImage)
//            Task {
//                let prepared = await source.byPreparingThumbnail(ofSize: smallSize)
//                await MainActor.run { thumbnail = prepared }
//            }
//        }
    }
}

// MARK: - Overlay View

struct RowID: Hashable {
    let sectionID: UUID
    let assetIndex: Int
}

struct PGLImageListOverlayView: View {
    // @ObservedObject var viewModel: PGLImageListViewModel
    @EnvironmentObject var viewModel: PGLImageListViewModel
    var onDismiss: () -> Void
    @State private var editMode: EditMode = .inactive //.active
    @State private var isAddingPhoto = false
    @State private var selectedRow: RowID?

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
            Text(viewModel.filterName)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button {
                isAddingPhoto = true
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .foregroundColor(selectedRow == nil ? .white.opacity(0.3) : .white)
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
                GeometryReader { geo in
                    let columnCount = max(viewModel.filterParms.count, 1)
                    let spacing: CGFloat = 12
                    let totalSpacing = spacing * CGFloat(columnCount - 1) + 24 // 12 padding each side
                    let columnWidth = (geo.size.width - totalSpacing) / CGFloat(columnCount)

                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(viewModel.filterParms) { imageAttributeSection in
                            sectionColumn(for: imageAttributeSection)
                                .frame(width: max(columnWidth, 160))
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .environment(\.editMode, $editMode)
                .sheet(isPresented: $isAddingPhoto) {
                    if let selectedRow {
                        PGLPhotoPicker(viewModel: viewModel, rowId: selectedRow)
                    }
                }
            }
        }
    }

    private func sectionColumn(for imageAttributeSection: ParmSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(imageAttributeSection.attributeName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            List {
                ForEach(Array(imageAttributeSection.assets.enumerated()), id: \.element.id) { assetIndex, pglAsset in
                    let cachedImage = pglAsset.thumbnail
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
