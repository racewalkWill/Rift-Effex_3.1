//
//  PGLGuide.swift
//  RiftEffects
//
//  Created by Will on 4/11/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import Foundation
import Photos
import UIKit
import os

    /// singleton instance for User Guided input
    /// Tracks steps to build example stack
@MainActor
public final class PGLGuide {
    static let Steps = PGLGuide()
    var userArrowSymbol = "arrowshape.forward.fill"
    var userSwipeArrow = "arrowshape.left.fill"
    var guideSteps: [PGLGuideStep]

    init() {
        guideSteps = [
            PGLGuideStep(controller: "PGLStackController",filter: nil, parmName: nil, label: userArrowSymbol ),
            PGLGuideStep(controller: "PGLMainFilterController",filter: "Stylize", parmName: nil,
                                  label: userArrowSymbol),
            PGLGuideStep(controller: "PGLMainFilterController",filter: "CIBlendWithMask", parmName: nil,
                                  label: userArrowSymbol),
            PGLGuideStep(controller: "PGLSelectParmController",filter: "CIBlendWithMask", parmName: "inputBackgroundImage",
                                  label: userArrowSymbol),
            PGLGuideStep(controller: "PGLSelectParmController",filter: "CIBlendWithMask", parmName: "inputMaskImage",
                                  label: userSwipeArrow),
            PGLGuideStep(controller: "PGLMainFilterController",filter: "CIRadialGradient", parmName: "nil",
                                  label: userArrowSymbol),
            PGLGuideStep(controller: "PGLSelectParmController",filter: "CIRadialGradient", parmName: "inputRadius0",
                                  label: userArrowSymbol),
            PGLGuideStep(controller: "PGLSelectParmController",filter: "CIRadialGradient", parmName: "inputRadius1",
                                  label: userArrowSymbol),
        ]

    }
    static func resetAll() {
        Steps.resetSteps()
    }
    func resetSteps() {
        guideSteps.forEach { $0.done = false }
    }

    func contains(_ step: PGLGuideStep) -> PGLGuideStep? {
       if let index = guideSteps.firstIndex(of: step)
        {   let matchStep = guideSteps[index ]
           matchStep.done = true
           // done prevents a second use of this step
           // the caller will always be looking for done = false
           return matchStep }
        else { return nil }
    }

}

class PGLGuideStep: Equatable {
    var controller: String = ""
    var filter: String?
    var parmName: String?
    var label: String = "arrowshape.forward.fill"
    var done: Bool = false

 static func == (lhs: PGLGuideStep, rhs: PGLGuideStep) -> Bool {
    return lhs.controller == rhs.controller &&
     lhs.filter == rhs.filter &&
     lhs.parmName == rhs.parmName &&
     lhs.done == rhs.done
     // label will be the action for the context
     //lhs.label == rhs.label

    }

    init(controller: String, filter: String? = nil, parmName: String? = nil, label: String = "arrowshape.forward.fill") {
        self.controller = controller
        self.filter = filter
        self.parmName = parmName
        self.label = label


    }
}
