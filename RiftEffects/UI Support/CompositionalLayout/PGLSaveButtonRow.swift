//
//  PGLSaveButtonRow.swift
//  RiftEffects
//
//  Created by Will on 11/12/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLSaveButtonRow: UITableViewCell {
    static let reuseIdentifer = "PGLSaveButtonRow-reuse-identifier"

    static let nibName = "SaveButtons"

    let containerView = UIView()

    @IBOutlet weak var saveBtn: UIButton! 
    
    @IBOutlet weak var cancelBtn: UIButton!
    

}
