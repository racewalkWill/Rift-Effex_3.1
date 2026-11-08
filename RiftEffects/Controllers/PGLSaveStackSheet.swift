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
/// Layout.preferredSize(showsVideoRow:showsWheel:) so the dialog stays small instead of covering the window.
struct PGLSaveStackSheet: View {
    @State private var titleText: String
    @State private var albumText: String
    @State private var isVideo = false   // false saves a single frame (zero seconds)
    @State private var minutes: Int
    @State private var seconds: Int

    let originalTitle: String
    let originalAlbum: String
    let existingAlbums: [String]
    let showsRunSeconds: Bool
    let isNewStack: Bool
    let maxMinutes: Int
    let onCancel: () -> Void
    let onVideoToggle: (_ isVideo: Bool) -> Void
    let onSave: (_ title: String, _ album: String, _ seconds: Int?) -> Void

    init(originalTitle: String,
         originalAlbum: String,
         existingAlbums: [String],
         showsRunSeconds: Bool,
         estimatedSeconds: Int,
         isNewStack: Bool,
         onCancel: @escaping () -> Void,
         onVideoToggle: @escaping (_ isVideo: Bool) -> Void,
         onSave: @escaping (_ title: String, _ album: String, _ seconds: Int?) -> Void) {
        self.originalTitle = originalTitle
        self.originalAlbum = originalAlbum
        self.existingAlbums = existingAlbums
        self.showsRunSeconds = showsRunSeconds
        self.isNewStack = isNewStack
        self.onCancel = onCancel
        self.onVideoToggle = onVideoToggle
        self.onSave = onSave
        _titleText = State(initialValue: originalTitle)
        _albumText = State(initialValue: originalAlbum)
        // timer wheel defaults to the estimated run time
        let estimate = max(estimatedSeconds, 0)
        _minutes = State(initialValue: estimate / 60)
        _seconds = State(initialValue: estimate % 60)
        // never clip a long estimate off the end of the minutes wheel
        self.maxMinutes = max(59, estimate / 60)
    }

    private var isDirty: Bool {
        // a stack that has never been saved has nothing to "Save As" a divergent copy of
        guard !isNewStack else { return false }
        return titleText != originalTitle || albumText != originalAlbum
    }

    /// Layout constants shared with PGLStackController#presentSaveStackSheet(), which uses
    /// Layout.preferredSize(showsVideoRow:showsWheel:) to size the popover/sheet to match this content.
    /// The size changes when the Video toggle shows or hides the timer wheel (see onVideoToggle).
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
        static let wheelHeight: CGFloat = 120
        static let wheelColumnWidth: CGFloat = 100

        static func preferredSize(showsVideoRow: Bool, showsWheel: Bool) -> CGSize {
            let rowCount = showsVideoRow ? 3 : 2
            var contentHeight = topPadding
                + CGFloat(rowCount) * rowHeight
                + CGFloat(rowCount - 1) * verticalRowSpacing
                + bottomPadding
            if showsVideoRow && showsWheel {
                contentHeight += verticalRowSpacing + wheelHeight
            }
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
                        Text(NSLocalizedString("Video", comment: "Save stack as video toggle label"))
                            .frame(width: Layout.labelWidth, alignment: .leading)
                        Toggle("", isOn: $isVideo.animation())
                            .labelsHidden()
                            .frame(width: Layout.fieldWidth, alignment: .trailing)
                    }
                    .frame(height: Layout.rowHeight)

                    if isVideo {
                        timerWheel
                            .transition(.opacity)
                    }
                }
            }
            .onChange(of: isVideo) { _, newValue in
                onVideoToggle(newValue)
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
                        // Video off saves a single frame as zero seconds
                        onSave(titleText, albumText, isVideo ? minutes * 60 + seconds : 0)
                    }
                }
            }
        }
    }

    /// minutes : seconds wheels for the video length.
    /// Two wheel Pickers because UIDatePicker .countDownTimer only offers hours and minutes.
    private var timerWheel: some View {
        HStack(spacing: 0) {
            Picker(NSLocalizedString("Minutes", comment: "Video length minutes wheel"), selection: $minutes) {
                ForEach(0...maxMinutes, id: \.self) { value in
                    Text(String(format: NSLocalizedString("%d min", comment: "Video length minutes wheel row"), value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: Layout.wheelColumnWidth)
            .clipped()

            Picker(NSLocalizedString("Seconds", comment: "Video length seconds wheel"), selection: $seconds) {
                ForEach(0...59, id: \.self) { value in
                    Text(String(format: NSLocalizedString("%d sec", comment: "Video length seconds wheel row"), value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: Layout.wheelColumnWidth)
            .clipped()
        }
        .frame(height: Layout.wheelHeight)
        .frame(maxWidth: .infinity)
    }
}
