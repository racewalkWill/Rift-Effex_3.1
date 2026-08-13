//
//  PGLSaveStackSheet.swift
//  RiftEffects
//
//  Created by Will Loew-Blosser on 8/13/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import SwiftUI

/// Modal replacement for the old inline "title/album/save" table rows in PGLStackController.
/// Presented via UIHostingController from PGLStackController#presentSaveStackSheet(), sized to
/// Layout.preferredSize(showsRunSeconds:) so the dialog stays small instead of covering the window.
struct PGLSaveStackSheet: View {
    @State private var titleText: String
    @State private var albumText: String
    @State private var secondsText: String

    let originalTitle: String
    let originalAlbum: String
    let existingAlbums: [String]
    let showsRunSeconds: Bool
    let isNewStack: Bool
    let onCancel: () -> Void
    let onSave: (_ title: String, _ album: String, _ seconds: Int?) -> Void

    init(originalTitle: String,
         originalAlbum: String,
         existingAlbums: [String],
         showsRunSeconds: Bool,
         estimatedSeconds: Int,
         isNewStack: Bool,
         onCancel: @escaping () -> Void,
         onSave: @escaping (_ title: String, _ album: String, _ seconds: Int?) -> Void) {
        self.originalTitle = originalTitle
        self.originalAlbum = originalAlbum
        self.existingAlbums = existingAlbums
        self.showsRunSeconds = showsRunSeconds
        self.isNewStack = isNewStack
        self.onCancel = onCancel
        self.onSave = onSave
        _titleText = State(initialValue: originalTitle)
        _albumText = State(initialValue: originalAlbum)
        _secondsText = State(initialValue: showsRunSeconds ? String(estimatedSeconds) : "")
    }

    private var isDirty: Bool {
        // a stack that has never been saved has nothing to "Save As" a divergent copy of
        guard !isNewStack else { return false }
        return titleText != originalTitle || albumText != originalAlbum
    }

    /// Layout constants shared with PGLStackController#presentSaveStackSheet(), which uses
    /// Layout.preferredSize(showsRunSeconds:) to size the popover/sheet to match this content.
    enum Layout {
        static let labelWidth: CGFloat = 70
        static let fieldWidth: CGFloat = 230       // ~30 characters at body text size
        static let bookmarkColumnWidth: CGFloat = 30
        static let rowSpacing: CGFloat = 6
        static let rowHeight: CGFloat = 36
        static let verticalRowSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 20     // bottom field sits ~20pt above the dialog's bottom edge
        static let navigationBarHeight: CGFloat = 44

        static func preferredSize(showsRunSeconds: Bool) -> CGSize {
            let rowCount = showsRunSeconds ? 3 : 2
            let contentHeight = topPadding
                + CGFloat(rowCount) * rowHeight
                + CGFloat(rowCount - 1) * verticalRowSpacing
                + bottomPadding
            let width = horizontalPadding * 2 + bookmarkColumnWidth + rowSpacing + labelWidth + fieldWidth
            return CGSize(width: width, height: contentHeight + navigationBarHeight)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Layout.verticalRowSpacing) {
                HStack(spacing: Layout.rowSpacing) {
                    Color.clear.frame(width: Layout.bookmarkColumnWidth, height: 1)
                    Text(NSLocalizedString("Title:", comment: "Stack title field label"))
                        .frame(width: Layout.labelWidth, alignment: .leading)
                    TextField("", text: $titleText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: Layout.fieldWidth)
                }

                HStack(spacing: Layout.rowSpacing) {
                    Menu {
                        ForEach(existingAlbums, id: \.self) { name in
                            Button(name) { albumText = name }
                        }
                    } label: {
                        Image(systemName: "bookmark")
                            .frame(width: Layout.bookmarkColumnWidth)
                    }
                    Text(NSLocalizedString("Album:", comment: "Stack album field label"))
                        .frame(width: Layout.labelWidth, alignment: .leading)
                    TextField("", text: $albumText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: Layout.fieldWidth)
                }

                if showsRunSeconds {
                    HStack(spacing: Layout.rowSpacing) {
                        Color.clear.frame(width: Layout.bookmarkColumnWidth, height: 1)
                        Text(NSLocalizedString("Seconds:", comment: "Stack run seconds field label"))
                            .frame(width: Layout.labelWidth, alignment: .leading)
                        TextField("", text: $secondsText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: Layout.fieldWidth)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.topPadding)
            .padding(.bottom, Layout.bottomPadding)
            .navigationTitle(Text("Save Stack", comment: "Save stack sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel button title"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isDirty ? NSLocalizedString("Save As", comment: "Save As button title")
                                   : NSLocalizedString("Save", comment: "Save button title")) {
                        onSave(titleText, albumText, Int(secondsText))
                    }
                }
            }
        }
    }
}
