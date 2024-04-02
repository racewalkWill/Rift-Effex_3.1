//
//  PGLVectorScaling.swift
//  RiftEffects
//
//  Created by Will on 4/1/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation

/// carries a viewHeight and scaleFactor for translation of vector to the view frame
class PGLVectorScaling  {
    var viewHeight: CGFloat = 1.0
    var viewScale: CGFloat = 1.0

    init(viewHeight: CGFloat, viewScale: CGFloat) {
        self.viewHeight = viewHeight
        self.viewScale = viewScale
    }
}
