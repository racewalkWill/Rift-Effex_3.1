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

}
