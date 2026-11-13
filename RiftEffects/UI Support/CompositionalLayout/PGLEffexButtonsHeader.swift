//
//  PGLEffexButtonsHeader.swift
//  RiftEffects
//
//  Created by Will on 11/6/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLEffexButtonsHeader: UITableViewHeaderFooterView {
    static let reuseIdentifer = "EffexButtonsHeader-reuse-identifier"

    static let nibName = "PGLEffexButtonsHeader"

    let containerView = UIView()

    @IBOutlet weak var addFilterBtn: UIButton!
    
    @IBOutlet weak var editFiltersBtn: UIButton!
    
    @IBAction func editFiltersBtn(_ sender: UIButton) {
        sender.isSelected.toggle()
    }
    /// arrow hint for PGLDemo.DemoMode  - usually hidden
    @IBOutlet weak var arrowBtn: UIButton!

    @IBOutlet weak var imageListBtn: UIButton!

    /// Center the visible buttons in the header width. The xib buttons are
    /// fixed frames for a 320pt column, so the last button clipped in narrower
    /// columns (iPhone Duo portrait stack column is 240pt). When the GuideMode
    /// arrow is shown it sits just left of addFilterBtn in the centered group.
    override func layoutSubviews() {
        super.layoutSubviews()
        let allButtons: [UIButton?] = [arrowBtn, addFilterBtn, editFiltersBtn, imageListBtn]
        let rowButtons = allButtons.compactMap { $0 }.filter { !$0.isHidden }
        guard let container = rowButtons.first?.superview else { return }

        let spacing: CGFloat = 8
        let totalWidth = rowButtons.reduce(0) { $0 + $1.frame.width }
            + spacing * CGFloat(rowButtons.count - 1)
        var x = max(0, (container.bounds.width - totalWidth) / 2)
        for button in rowButtons {
            button.frame.origin.x = x
            x += button.frame.width + spacing
        }
    }

}
