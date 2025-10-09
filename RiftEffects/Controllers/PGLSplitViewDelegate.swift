//
//  PGLSplitViewDelegate.swift
//  RiftEffects
//
//  Created by Will on 10/7/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

class PGLSplitViewDelegate:  UISplitViewControllerDelegate  {

        // MARK: Delegate overrides


//    Specifying the interface orientations
    func splitViewControllerPreferredInterfaceOrientationForPresentation(_: UISplitViewController) -> UIInterfaceOrientation {
            //      Asks the delegate for the orientation to use when presenting the split view controller.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
        return .landscapeLeft
    }

    func splitViewControllerSupportedInterfaceOrientations(_: UISplitViewController) -> UIInterfaceOrientationMask {
            //        Asks the delegate to specify the interface orientations that the split view controller supports.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
        return .landscapeLeft
    }

//        Responding to display mode changes
    func splitViewController(_: UISplitViewController, willChangeTo: UISplitViewController.DisplayMode) {
            //        Tells the delegate that the display mode for the split view controller is about to change.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function) willChangeTo= \(String(describing: willChangeTo))")
    }


    func targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewController.DisplayMode {
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
        let horizontalSize = svc.traitCollection.horizontalSizeClass
        if horizontalSize == .compact {
            return .oneBesideSecondary
        }
        return .twoDisplaceSecondary
    }

//            Collapsing the interface
    @objc   func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
            //horizontally regular to a horizontally compact size class
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\( String(describing: self) + "-" + #function)")
        return proposedTopColumn

    }

    func splitViewController(_: UISplitViewController, willHide: UISplitViewController.Column) {
            //            Tells the delegate that the specified column is about to be hidden.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
    }
    @objc func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
            //            Tells the delegate that the split view controller interface has collapsed.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
        
    }


    //            Expanding the interface
    func splitViewController(_: UISplitViewController, displayModeForExpandingToProposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
            //            Asks the delegate to provide the display mode to use after the split view interface expands.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
        return displayModeForExpandingToProposedDisplayMode
    }

    func splitViewController(_: UISplitViewController, willShow: UISplitViewController.Column) {
            //            Tells the delegate that the specified column is about to be shown.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
    }

    func splitViewControllerDidExpand(_: UISplitViewController) {
            //            Tells the delegate that the split view controller interface has expanded.
        Logger(subsystem: LogSubsystem, category: LogCategory).notice("\(String(describing: self)) - \(#function)")
    }
                // END Delegate methods
}

