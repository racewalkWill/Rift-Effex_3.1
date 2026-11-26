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
/// a filter's PGLParmMapping changed - the point parms now map to other view positions
let PGLParmMappingChange = NSNotification.Name(rawValue: "PGLParmMappingChange")
let PGLTransitionExists = NSNotification.Name(rawValue: "PGLTransitionExists")
let PGLVaryTimerRunning = NSNotification.Name(rawValue: "PGLVaryTimerRunning")
let PGLResetNeedsRedraw = NSNotification.Name(rawValue: "PGLResetNeedsRedraw")
/// Trash 'Remove Images' - animation state is .none until an image input is added
let PGLClearAnimationState = NSNotification.Name(rawValue: "PGLClearAnimationState")
/// an image parm has new image input - ends the PGLClearAnimationState .none
let PGLImageInputAdded = NSNotification.Name(rawValue: "PGLImageInputAdded")
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
    var videoSourceExists = false

    var viewWillAppear = false
    private var viewWillAppearCounter = 0

    /// true after Trash 'Remove Images' until an image input is added.
    /// Vary timers keep running and stay counted, but with no images the state is .none
    private var imagesRemoved = false

    private var transitionFilterCount = 0
    private var varyTimerCount = 0
    private var videoCount = 0

//    let myCenter =  NotificationCenter.default

    var publishers = [any Cancellable]()
    var cancellable: (any Cancellable)?
    init(){
        // register for changes

        cancellable = NotificationCenter.default.publisher(for: PGLRedrawParmControllerOpenNotification)
            .sink() {   [weak self]
                myUpdate in
                if let userDataDict = myUpdate.userInfo {
                    if let parmOpenFlag = userDataDict["parmControllerIsOpen"]  as? Bool {
                        self?.parmController(isOpen: parmOpenFlag)
                    }
                }
            }

        publishers.append(cancellable!)


        cancellable = NotificationCenter.default.publisher(for: PGLRedrawFilterChange )
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

        cancellable = NotificationCenter.default.publisher(for: PGLTransitionExists)
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


        cancellable = NotificationCenter.default.publisher(for: PGLVideoSourceStateChanged)
            .sink() {
            [weak self]
            myUpdate in
            if let userDataDict = myUpdate.userInfo {
                if let changeCount = userDataDict["videoSourceStateChange"]   {
                    NSLog("PGLRedraw: videoSourceStateChange: \(changeCount) ")
                    self?.changeVideo(count: changeCount as! Int)
                }
            }
        }
        publishers.append(cancellable!)

        cancellable = NotificationCenter.default.publisher(for:  PGLVaryTimerRunning  )
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

        cancellable = NotificationCenter.default.publisher(for:  PGLPauseAnimation )
            .sink() {
            [weak self]
            myUpdate in
            self?.pauseAnimation = !(self?.pauseAnimation ?? true)
            self?.publishAnimationState()
                // defaults to !true  ie false
        }
        publishers.append(cancellable!)

        //PGLResetNeedsRedraw
        cancellable = NotificationCenter.default.publisher(for: PGLResetNeedsRedraw )
            .sink() {
            [weak self]
            myUpdate in
            self?.parmControllerIsOpen = false
            self?.filterChanged = false
            self?.clearAnimationCounts()
            self?.viewWillAppear = false
            self?.viewWillAppearCounter = 0
            self?.isFullScreen = false
            self?.publishAnimationState()
        }
        publishers.append(cancellable!)

        // Trash 'Remove Images' - the stack stays displayed so the parm controller
        // and full screen flags are kept
        cancellable = NotificationCenter.default.publisher(for: PGLClearAnimationState )
            .sink() {
            [weak self]
            myUpdate in
            self?.clearImageAnimationCounts()
            self?.publishAnimationState()
        }
        publishers.append(cancellable!)

        cancellable = NotificationCenter.default.publisher(for: PGLImageInputAdded )
            .sink() {
            [weak self]
            myUpdate in
            self?.imageInputAdded()
        }
        publishers.append(cancellable!)

        cancellable = NotificationCenter.default.publisher(for:  PGLImageViewWillAppear )
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
//            NSLog("toggleViewWillAppear counter =  \(viewWillAppearCounter)")
//            Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " viewWillAppear set to \(String(describing: self.viewWillAppearCounter))") "))

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

    private func videoCount(exists: Bool) {
        videoSourceExists = exists
    }

    private func varyTimer(isRunning: Bool) {
        varyTimerIsRunning = isRunning
    }

    func filter(changed: Bool) {

        filterChanged = changed
    }

    fileprivate func publishAnimationState() {

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

    func changeVideo(count: Int) {
        // count parm is +1 or -1
        // pass neg -1 to decrement
        videoCount += count
        if videoCount < 0 { videoCount = 0 }
        NSLog("PGLRedraw: videoCount = \(videoCount) ")
        videoCount(exists: videoCount > 0 )
        if oldAnimationState != animationState() {
            publishAnimationState()
            oldAnimationState = animationState()
        }
    }

    func changeVaryTimerCount(count: Int) {
            // count parm is +1 or -1
            // pass neg -1 to decrement
        varyTimerCount += count
        if varyTimerCount < 0 { varyTimerCount = 0 }
            // keep the count from going negative if a Vary off is posted after a reset
        varyTimer(isRunning: varyTimerCount > 0)
        if oldAnimationState != animationState() {
            publishAnimationState()
            oldAnimationState = animationState()
        }
    }

    /// zero every animation source so animationState() answers .none
    /// used by the PGLResetNeedsRedraw of a released stack
    func clearAnimationCounts() {
        clearImageAnimationCounts()
        varyTimerCount = 0
        varyTimerIsRunning = false
        imagesRemoved = false
    }

    /// Trash 'Remove Images' - zero the image driven transition & video counts.
    /// Vary timers keep running on the filters so their count is kept;
    /// imagesRemoved answers .none until imageInputAdded()
    /// leaves parmControllerIsOpen & isFullScreen alone - the stack is still displayed
    func clearImageAnimationCounts() {
        transitionFilterCount = 0
        transitionFilterExists = false
        videoCount = 0
        videoSourceExists = false
        pauseAnimation = false
        imagesRemoved = true
        oldAnimationState = PGLAnimationState.none
    }

    /// new image input after 'Remove Images' - a running Vary timer shows the button again
    func imageInputAdded() {
        if !imagesRemoved { return }
        imagesRemoved = false
        if oldAnimationState != animationState() {
            publishAnimationState()
            oldAnimationState = animationState()
        }
    }

    func animationState() -> PGLAnimationState {
        if imagesRemoved {
            return .none
        }
        if !transitionFilterExists && !varyTimerIsRunning && !videoSourceExists {

            return .none
        }
        if pauseAnimation {
            return .paused  }
        else  {
            return .running }

    }


}
