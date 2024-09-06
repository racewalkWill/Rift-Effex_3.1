//
//  PGLNeedsRedraw.swift
//  RiftEffects
//
//  Created by Will on 1/15/23.
//  Copyright © 2023 Will Loew-Blosser. All rights reserved.
//

import Foundation
import Combine
import os

let PGLRedrawParmControllerOpenNotification = NSNotification.Name(rawValue: "PGLRedrawParmControllerOpenNotification")
let PGLRedrawFilterChange = NSNotification.Name(rawValue: "PGLRedrawFilterChange")
let PGLTransitionExists = NSNotification.Name(rawValue: "PGLTransitionExists")
let PGLVaryTimerRunning = NSNotification.Name(rawValue: "PGLVaryTimerRunning")
let PGLResetNeedsRedraw = NSNotification.Name(rawValue: "PGLResetNeedsRedraw")
let PGLPauseAnimation = NSNotification.Name(rawValue: "PGLPauseAnimation")
let PGLAnimationStateChanged = NSNotification.Name(rawValue: "PGLAnimationStateChanged")
let PGLImageViewWillAppear = NSNotification.Name(rawValue: "PGLImageViewWillAppear")


enum PGLAnimationState {
    case none
    case running
    case paused
}

@MainActor
class PGLRedraw {
    // answers true  redrawNow() if mtkView should draw
    //   prmControllerIsOpen || transitionFilterExists || varyTimerIsRunning || filterChanged
    // answers  true imageAnimationRunning() if transitionFilterExists || varyTimerIsRunning
    var parmControllerIsOpen = false
    var transitionFilterExists = false
    var varyTimerIsRunning = false
    var filterChanged = false
    var pauseAnimation = false
    var oldAnimationState = PGLAnimationState.none
    var appStackVideoMgr: PGLVideoMgr?
    var isFullScreen = false

    var viewWillAppear = false
    private var viewWillAppearCounter = 0

    private var transitionFilterCount = 0
    private var varyTimerCount = 0

    let myCenter =  NotificationCenter.default

    var publishers = [Cancellable]()
    var cancellable: Cancellable?
    init(){
        // register for changes

        cancellable = myCenter.publisher(for: PGLRedrawParmControllerOpenNotification)
            .sink() {   [weak self]
                myUpdate in
                if let userDataDict = myUpdate.userInfo {
                    if let parmOpenFlag = userDataDict["parmControllerIsOpen"]  as? Bool {
                        self?.parmController(isOpen: parmOpenFlag)
                    }
                }
            }

        publishers.append(cancellable!)


        cancellable = myCenter.publisher(for: PGLRedrawFilterChange )
            .sink() {
            [weak self]
            myUpdate in
            if let userDataDict = myUpdate.userInfo {
                if let changeFlag = userDataDict["filterHasChanged"]  as? Bool {
                    self?.filter(changed: changeFlag)
                }
            }
        }
        publishers.append(cancellable!)

        cancellable = myCenter.publisher(for: PGLTransitionExists)
            .sink() {
            [weak self]
            myUpdate in
            if let userDataDict = myUpdate.userInfo {
                if let changeCount = userDataDict["transitionFilterAdd"]   {
                    NSLog("PGLRedraw: transitionExists: \(changeCount) ")
                    self?.changeTransitionFilter(count: changeCount as! Int)
                }
            }
        }
        publishers.append(cancellable!)

        cancellable = myCenter.publisher(for:  PGLVaryTimerRunning  )
            .sink() {
            [weak self]
            myUpdate in
            if let userDataDict = myUpdate.userInfo {
                if let changeCount = (userDataDict["varyTimerChange"]) as? Int  {
                    self?.changeVaryTimerCount(count: changeCount)
                }
            }
        }
        publishers.append(cancellable!)

        cancellable = myCenter.publisher(for:  PGLPauseAnimation )
            .sink() {
            [weak self]
            myUpdate in
            self?.pauseAnimation = !(self?.pauseAnimation ?? true)
            self?.publishAnimationState()
                // defaults to !true  ie false
        }
        publishers.append(cancellable!)

        //PGLResetNeedsRedraw
        cancellable = myCenter.publisher(for: PGLResetNeedsRedraw )
            .sink() {
            [weak self]
            myUpdate in
            self?.parmControllerIsOpen = false
            self?.transitionFilterExists = false
            self?.varyTimerIsRunning = false
            self?.filterChanged = false
            self?.pauseAnimation = false
            self?.oldAnimationState = PGLAnimationState.none
            self?.transitionFilterCount = 0
            self?.varyTimerCount = 0
            self?.viewWillAppear = false
            self?.viewWillAppearCounter = 0
            self?.isFullScreen = false
            self?.publishAnimationState()
        }
        publishers.append(cancellable!)

        cancellable = myCenter.publisher(for:  PGLImageViewWillAppear )
            .sink() {
            [weak self]
            myUpdate in
            self?.viewWillAppear = true
//          Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function) PGLImageViewWillAppear: signaled")
//            NSLog("PGLRedraw: PGLImageViewWillAppear: signaled ")
        }
        publishers.append(cancellable!)


    } // end init
    
    func redrawNow() -> Bool {
        // answer true if any condition is true
        let needsRedraw = viewWillAppear || parmControllerIsOpen || transitionFilterExists || varyTimerIsRunning || filterChanged || videoExists() || isFullScreen
//        if needsRedraw {
//            NSLog ("redrawNow: true")
//        }
        return needsRedraw
    }

    func toggleViewWillAppear() {
        // go twice, then reset
        if viewWillAppearCounter < 3 {
            viewWillAppearCounter += 1
            NSLog("toggleViewWillAppear counter =  \(viewWillAppearCounter)")

//            NSLog("toggleViewWillAppear: \(viewWillAppear)")
        } else {
            viewWillAppearCounter = 0
            viewWillAppear = false
            NSLog("toggleViewWillAppear: \(viewWillAppear)")
        }

    }

    func toggleFilterChanged() {
        filterChanged = !filterChanged // sets to false if was previously true
    }

    func videoExists() -> Bool {
        return appStackVideoMgr?.videoExists() ?? false
    }

    func shouldPauseAnimation() -> Bool {
       return pauseAnimation
    }


    func parmController(isOpen: Bool) {
        parmControllerIsOpen = isOpen
    }

    private func transitionFilter(exists: Bool) {
        transitionFilterExists = exists
    }

    private func varyTimer(isRunning: Bool) {
        varyTimerIsRunning = isRunning
    }

    func filter(changed: Bool) {

        filterChanged = changed
    }

    fileprivate func publishAnimationState() {
//        let animationStateChangeNotice = Notification.Name("PGLAnimationStateChanged")
        let userInfo: [String: Any] = ["animationState": animationState()]
        NotificationCenter.default.post(name: PGLAnimationStateChanged, object: nil, userInfo: userInfo)
    }
    
    func changeTransitionFilter(count: Int) {
        // count parm is +1 or -1
        // pass neg -1 to decrement
        transitionFilterCount += count
        if transitionFilterCount < 0 { transitionFilterCount = 0 }
        NSLog("PGLRedraw: changeTransitionFilter: transitionFilterCount = \(transitionFilterCount) ")
        transitionFilter(exists: transitionFilterCount > 0 )
        if oldAnimationState != animationState() {
            publishAnimationState()
            oldAnimationState = animationState()
        }
    }

    func changeVaryTimerCount(count: Int) {
            // count parm is +1 or -1
            // pass neg -1 to decrement
        varyTimerCount += count
        varyTimer(isRunning: varyTimerCount > 0)
        if oldAnimationState != animationState() {
            publishAnimationState()
            oldAnimationState = animationState()
        }
    }

    func animationState() -> PGLAnimationState {
        if !transitionFilterExists && !varyTimerIsRunning {
            // could add videoExists with new way to stop the video..
            return .none
        }
        if pauseAnimation {
            return .paused  }
        else  {
            return .running }

    }


}
