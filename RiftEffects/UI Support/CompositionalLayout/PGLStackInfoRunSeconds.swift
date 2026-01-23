//
//  PGLStackInfoHeader 2.swift
//  RiftEffects
//
//  Created by Will on 1/22/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//


//
//  PGLStackInfoHeader.swift
//  RiftEffects
//
//  Created by Will on 8/9/23.
//  Copyright © 2023 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLStackInfoRunSeconds: UITableViewCell, UITextFieldDelegate {

    var secondsValue = 0
    static let reuseIdentifer = "PGLStackInfoRunSeconds-reuse-identifier"

    static let nibName = "PGLStackRunSeconds"

    let containerView = UIView()

    @IBOutlet weak var cellLabel: UILabel!

    @IBOutlet weak var userSeconds: UITextField!

    @IBAction func userSecondChanged(_ sender: UITextField) {
        let digitsOnly = sender.text?.filter { $0.isNumber } ?? ""
        if digitsOnly != sender.text {
            sender.text = digitsOnly
        }
        secondsValue = Int(digitsOnly) ?? 0

    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()
        return true
    }

}
