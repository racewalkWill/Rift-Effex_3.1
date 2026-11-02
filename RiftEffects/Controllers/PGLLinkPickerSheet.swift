//
//  PGLLinkPickerSheet.swift
//  RiftEffects
//
//  Created by Will Loew-Blosser on 11/2/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import SwiftUI

/// Multi-select picker for the Link swipe action of a link master parm.
/// Rows toggle a checkmark - pick one, two or many targets, then confirm with Link.
/// Select All checks every candidate in the Link All set; points of the master's own
/// filter are not in that set (see PGLFilterAttribute #linkAllIncludes) but can be checked by hand.
/// Presented via UIHostingController from PGLSelectParmController#presentLinkPicker.
struct PGLLinkPickerSheet: View {

    struct Candidate: Identifiable {
        let id: ObjectIdentifier
        let name: String        // parentParmFilterName() - "Droste>Inset Point 0"
        let inLinkAll: Bool     // master.linkAllIncludes(candidate)
    }

    enum Layout {
        static let width: CGFloat = 360
        static let rowHeight: CGFloat = 48
        static let chromeHeight: CGFloat = 190  // navigation bar, Select All row and message footer

        static func preferredSize(candidateCount: Int) -> CGSize {
            let listHeight = rowHeight * CGFloat(candidateCount)
            return CGSize(width: width, height: min(chromeHeight + listHeight, 560))
        }
    }

    let title: String
    let message: String
    let candidates: [Candidate]
    let onCancel: () -> Void
    let onLink: ([ObjectIdentifier]) -> Void

    @State private var selected = Set<ObjectIdentifier>()

    /// the candidates that Select All checks
    private var linkAllIds: Set<ObjectIdentifier> {
        Set(candidates.filter { $0.inLinkAll }.map { $0.id })
    }

    private var allSelected: Bool {
        !linkAllIds.isEmpty && linkAllIds.isSubset(of: selected)
    }

    var body: some View {
        NavigationStack {
            List {
                if !linkAllIds.isEmpty {
                    Section {
                        Button(allSelected ? "Deselect All" : "Select All") {
                            toggleAll()
                        }
                    }
                }
                Section {
                    ForEach(candidates) { candidate in
                        Button {
                            toggle(candidate.id)
                        } label: {
                            HStack {
                                Text(candidate.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(candidate.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(selected.contains(candidate.id) ? .isSelected : [])
                    }
                } footer: {
                    Text(message)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Link") {
                        onLink(Array(selected))
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: ObjectIdentifier) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func toggleAll() {
        if allSelected {
            selected.subtract(linkAllIds)
        } else {
            selected.formUnion(linkAllIds)
        }
    }
}
