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

enum StepViewState {
    case pending
    case completed
    case active
}

    /// singleton instance for User Guided input
    /// Tracks steps to build example stack
@MainActor
public final class PGLGuide {
    static let Steps = PGLGuide()
    var userArrowSymbol = "hand.point.right"
    var userSwipeArrow = "appwindow.swipe.rectangle" //arrowshape.left.fill"
    var userTouchSymbol = "hand.tap.fill"
    var guideSteps: [PGLGuideGroup]
    var currentGroup: PGLGuideGroup = PGLGuideGroup(steps: [PGLGuideStep]() )
    var currentGroupIndex: Int = 0

    init() {
        guideSteps = [ PGLGuideGroup(
                        steps: [
                            PGLGuideStep(controller: "PGLStackController",filter: nil, parmName: nil, label: userArrowSymbol ),
                         // the button symbol in file PGLEffexButtonsHader.xib not set from the label parm
                       ]) ,
                       PGLGuideGroup( steps: [
                            PGLGuideStep(controller: "PGLMainFilterController",filter: "Stylize", parmName: nil,
                                         label: userArrowSymbol),
                            PGLGuideStep(controller: "PGLMainFilterController",filter: "CIBlendWithMask", parmName: nil,
                                         label: userArrowSymbol),

                            PGLGuideStep(controller: "PGLSelectParmController",filter: "CIBlendWithMask", parmName: "inputBackgroundImage",
                                                  label: userTouchSymbol),
                            PGLGuideStep(controller: "PGLSelectParmController",filter: "CIBlendWithMask", parmName: "inputMaskImage",
                                                  label: userSwipeArrow),
                        ] ),
                       PGLGuideGroup( steps: [
                            PGLGuideStep(controller: "PGLMainFilterController",filter: "Gradient", parmName: nil,
                                                  label: userArrowSymbol),
                            PGLGuideStep(controller: "PGLMainFilterController",filter: "Triangle Gradient", parmName: nil,
                                                  label: userArrowSymbol),
                            PGLGuideStep(controller: "PGLSelectParmController",filter: "Triangle Gradient", parmName: "inputCenter",
                                                  label: userArrowSymbol),
                       ] ),
        ]
        currentGroup = guideSteps[0]
        currentGroup.state = .active
    }

    static func resetAll() {
        Steps.resetSteps()

    }
    func resetSteps() {
        guideSteps.forEach { $0.resetSteps() }
        currentGroupIndex = 0
        currentGroup = guideSteps[currentGroupIndex]
        if PGLDemo.GuideMode {
            currentGroup.state = .active
        }

    }

    func contains(_ step: PGLGuideStep) -> PGLGuideStep? {
        if let index = currentGroup.steps.firstIndex(of: step)
        {   let matchStep = currentGroup.steps[index ]
           matchStep.state = .active
           // done prevents a second use of this step
           // the caller will always be looking for state = pending
            if index == currentGroup.steps.count - 1 {
                // at end of this groups steps
                currentGroup.state = .completed
                currentGroupIndex = currentGroupIndex + 1
                if currentGroupIndex < guideSteps.count {
                    currentGroup = guideSteps[currentGroupIndex]
                    currentGroup.state = .active
                } else {
                    // at the end  reset and turn off DemoMode
                    PGLDemo.GuideMode = false
                        // resets all guides in the didSet block
                }
            }
           return matchStep }
        else { return nil }
    }

}
class PGLGuideGroup: Equatable {
    var steps: [PGLGuideStep] = []
    var state: StepViewState = .pending

    static func == (lhs: PGLGuideGroup, rhs: PGLGuideGroup) -> Bool {
        return lhs.steps == rhs.steps
    }

    init(steps: [PGLGuideStep]) {
        self.steps = steps

    }

    func resetSteps() {
        steps.forEach { $0.state = .pending }
        state = .pending
    }
}

class PGLGuideStep: Equatable {
    var controller: String = ""
    var filter: String?
    var parmName: String?
    var label: String = "hand.point.right"
    var state: StepViewState = .pending {
        didSet{
            NSLog("\(#function ) \(String(describing: filter)) \(String(describing: parmName)) \(state)" )

        }
    }

 static func == (lhs: PGLGuideStep, rhs: PGLGuideStep) -> Bool {
    return lhs.controller == rhs.controller &&
     lhs.filter == rhs.filter &&
     lhs.parmName == rhs.parmName &&
     lhs.state == rhs.state
     // label will be the action for the context
     //lhs.label == rhs.label

    }

    init(controller: String, filter: String? = nil, parmName: String? = nil, label: String = "hand.point.right" ) {
        self.controller = controller
        self.filter = filter
        self.parmName = parmName
        self.label = label


    }
}
